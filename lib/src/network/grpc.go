package network

import (
	"bufio"
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/centny/flame_network/lib/src/network/grpc"
	"github.com/codingeasygo/util/converter"
	"github.com/codingeasygo/util/uuid"
	"github.com/codingeasygo/util/xdebug"
	"github.com/codingeasygo/util/xmap"
	"github.com/codingeasygo/util/xtime"
	"golang.org/x/net/websocket"
	ggrpc "google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
)

type NetworkSessionValueGRPC metadata.MD

func (n NetworkSessionValueGRPC) ValueVal(path ...string) (v interface{}, err error) {
	for _, k := range path {
		vals := n[k]
		if len(vals) > 0 {
			v = vals[0]
			return
		}
	}
	err = fmt.Errorf("not exists")
	return
}
func (n NetworkSessionValueGRPC) SetValue(path string, val interface{}) (err error) {
	metadata.MD(n).Set(path, fmt.Sprintf("%v", val))
	return
}
func (n NetworkSessionValueGRPC) Delete(path string) (err error) {
	delete(n, path)
	return
}
func (n NetworkSessionValueGRPC) Clear() (err error) {
	for k := range n {
		delete(n, k)
	}
	return
}
func (n NetworkSessionValueGRPC) Length() (l int) {
	l = len(n)
	return
}
func (n NetworkSessionValueGRPC) Exist(path ...string) bool {
	for _, k := range path {
		if _, ok := n[k]; ok {
			return true
		}
	}
	return false
}

func NewNetworkSessionFromGRPC(ctx context.Context) (session *NetworkSession) {
	md, _ := metadata.FromIncomingContext(ctx)
	session = NewNetworkSession(xmap.NewSafeByBase(NetworkSessionValueGRPC(md)))
	return
}

func NewOutgoingContext(parent context.Context, session *NetworkSession) (ctx context.Context) {
	raw := session.Raw()
	switch raw := raw.(type) {
	case xmap.M:
		value := map[string]string{}
		for k, v := range raw {
			value[k] = fmt.Sprintf("%v", v)
		}
		ctx = metadata.NewOutgoingContext(parent, metadata.New(value))
	default:
		ctx = metadata.NewOutgoingContext(parent, metadata.MD(session.Raw().(NetworkSessionValueGRPC)))
	}
	return
}

func ParseSyncDataGRPC(data *NetworkSyncData) (sd *grpc.SyncData) {
	sd = &grpc.SyncData{
		Id:    &grpc.RequestID{Uuid: data.UUID},
		Group: data.Group,
		Whole: data.Whole,
	}
	for _, c := range data.Components {
		props := map[string]string{}
		for k, v := range c.Props {
			switch v.(type) {
			case float32, float64:
				props[k] = fmt.Sprintf("%.02f", v)
			default:
				props[k] = converter.JSON(v)
			}
		}
		sd.Components = append(sd.Components, &grpc.SyncDataComponent{
			FactoryType: c.Factory,
			Cid:         c.CID,
			Owner:       c.Owner,
			Removed:     c.Removed,
			Props:       converter.JSON(props),
			Triggers:    converter.JSON(c.Triggers),
		})
	}
	return
}

func ParseNetworkSyncDataGRPC(sd *grpc.SyncData) (data *NetworkSyncData) {
	data = &NetworkSyncData{
		UUID:  sd.Id.Uuid,
		Group: sd.Group,
		Whole: sd.Whole,
	}
	for _, c := range sd.Components {
		props, xerr := xmap.MapVal(c.Props)
		if xerr != nil {
			Warnf("[GRPC] parse network component props on %v/%v error %v", c.FactoryType, c.Cid, xerr)
			continue
		}
		triggers, xerr := xmap.MapVal(c.Triggers)
		if xerr != nil {
			Warnf("[GRPC] parse network component trigger on %v/%v error %v", c.FactoryType, c.Cid, xerr)
			continue
		}
		data.Components = append(data.Components, &NetworkSyncDataComponent{
			Factory:  c.FactoryType,
			CID:      c.Cid,
			Owner:    c.Owner,
			Removed:  c.Removed,
			Props:    props,
			Triggers: triggers,
		})
	}
	return
}

type NetworkBaseConnGRPC struct {
	session  *NetworkSession
	state    NetworkState
	isServer bool
	isClient bool
}

func (n *NetworkBaseConnGRPC) ID() string {
	return fmt.Sprintf("%p", n)
}
func (n *NetworkBaseConnGRPC) Session() *NetworkSession {
	return n.session
}
func (n *NetworkBaseConnGRPC) State() NetworkState {
	return n.state
}
func (n *NetworkBaseConnGRPC) IsServer() bool {
	return n.isServer
}
func (n *NetworkBaseConnGRPC) IsClient() bool {
	return n.isClient
}
func (n *NetworkBaseConnGRPC) NetworkSync(data *NetworkSyncData) {
}

type NetworkSyncStreamGRPC struct {
	*NetworkBaseConnGRPC
	stream grpc.Server_RemoteSyncServer
	closer chan string
}

func NewNetworkSyncStreamGRPC(session *NetworkSession, stream grpc.Server_RemoteSyncServer) (sync *NetworkSyncStreamGRPC) {
	sync = &NetworkSyncStreamGRPC{
		NetworkBaseConnGRPC: &NetworkBaseConnGRPC{
			session:  session,
			state:    NetworkStateReady,
			isServer: true,
			isClient: true,
		},
		stream: stream,
		closer: make(chan string, 1),
	}
	return
}

func (n *NetworkSyncStreamGRPC) Wait() (err error) {
	m := <-n.closer
	err = fmt.Errorf(m)
	return
}

func (n *NetworkSyncStreamGRPC) Send(data *grpc.SyncData) (err error) {
	if n.stream != nil {
		err = n.stream.Send(data)
	}
	return
}

func (n *NetworkSyncStreamGRPC) NetworkSync(data *NetworkSyncData) {
	n.Send(ParseSyncDataGRPC(data))
}

func (n *NetworkSyncStreamGRPC) Close() (err error) {
	select {
	case n.closer <- "closed":
	default:
	}
	return
}

type NetworkServerGRPC struct {
	grpc.UnimplementedServerServer
	callback   NetworkCallback
	connAll    map[string]map[string]*NetworkSyncStreamGRPC
	connGroup  map[string]map[string]*NetworkSyncStreamGRPC
	sessionAll map[string]*NetworkBaseConnGRPC
	lock       sync.RWMutex
}

func NewNetworkServerGRPC(callback NetworkCallback) (server *NetworkServerGRPC) {
	server = &NetworkServerGRPC{
		callback:   callback,
		connAll:    map[string]map[string]*NetworkSyncStreamGRPC{},
		connGroup:  map[string]map[string]*NetworkSyncStreamGRPC{},
		sessionAll: map[string]*NetworkBaseConnGRPC{},
		lock:       sync.RWMutex{},
	}
	return
}

func (n *NetworkServerGRPC) keepSession(session *NetworkSession) NetworkConnection {
	n.lock.Lock()
	defer n.lock.Unlock()
	sid := session.Session()
	having := n.sessionAll[sid]
	if having == nil {
		having = &NetworkBaseConnGRPC{
			session:  session,
			state:    NetworkStateReady,
			isServer: true,
			isClient: true,
		}
		n.sessionAll[sid] = having
	}
	having.session.Last = time.Now()
	having.session = session
	return having
}

func (n *NetworkServerGRPC) sessionTimeout(max time.Duration) []*NetworkBaseConnGRPC {
	n.lock.RLock()
	defer n.lock.RUnlock()
	sessionAll := []*NetworkBaseConnGRPC{}
	for k, s := range n.sessionAll {
		if time.Since(s.session.Last) > max {
			sessionAll = append(sessionAll, s)
			delete(n.sessionAll, k)
		}
	}
	return sessionAll
}

func (n *NetworkServerGRPC) sessionConnAll(session string) map[string]*NetworkSyncStreamGRPC {
	connAll := n.connAll[session]
	if connAll == nil {
		connAll = map[string]*NetworkSyncStreamGRPC{}
		n.connAll[session] = connAll
	}
	return connAll
}

func (n *NetworkServerGRPC) sessionConnCopy(session string) NetworkConnectionSet {
	n.lock.Lock()
	defer n.lock.Unlock()
	connAll := NetworkConnectionSet{}
	for k, v := range n.connAll[session] {
		connAll[k] = v
	}
	return connAll
}

func (n *NetworkServerGRPC) groupConnAll(group string) map[string]*NetworkSyncStreamGRPC {
	connGroup := n.connGroup[group]
	if connGroup == nil {
		connGroup = map[string]*NetworkSyncStreamGRPC{}
		n.connGroup[group] = connGroup
	}
	return connGroup
}

func (n *NetworkServerGRPC) groupConnCopy(group string) map[string]*NetworkSyncStreamGRPC {
	n.lock.Lock()
	defer n.lock.Unlock()
	connGroup := map[string]*NetworkSyncStreamGRPC{}
	for k, v := range n.connGroup[group] {
		connGroup[k] = v
	}
	return connGroup
}

func (n *NetworkServerGRPC) addStream(stream *NetworkSyncStreamGRPC) {
	n.lock.Lock()
	defer func() {
		n.lock.Unlock()
		n.networkState(stream, NetworkStateReady, nil)
	}()
	sid := stream.ID()
	session := stream.session.Session()
	group := stream.session.Group()
	n.sessionConnAll(session)[sid] = stream
	n.groupConnAll(group)[sid] = stream
	n.groupConnAll("*")[sid] = stream
	Debugf("[GRPC] add one network sync stream on %v/%v/%v", group, stream.session.User(), session)
}

func (n *NetworkServerGRPC) cancleStream(stream *NetworkSyncStreamGRPC) {
	n.lock.Lock()
	defer func() {
		n.lock.Unlock()
		n.networkState(stream, NetworkStateClosed, nil)
	}()
	sid := stream.ID()
	session := stream.session.Session()
	group := stream.session.Group()
	delete(n.sessionConnAll(session), sid)
	delete(n.groupConnAll(group), sid)
	delete(n.groupConnAll("*"), sid)
	Debugf("[GRPC] remove network sync stream on %v/%v/%v", group, stream.session.User(), session)
}

func (n *NetworkServerGRPC) networkState(conn NetworkConnection, state NetworkState, info interface{}) {
	n.callback.OnNetworkState(n.sessionConnCopy(conn.Session().Session()), conn, state, info)
}

func (n *NetworkServerGRPC) timeout(max time.Duration) {
	for _, s := range n.sessionTimeout(max) {
		for _, c := range n.sessionConnCopy(s.session.Session()) {
			c.(*NetworkSyncStreamGRPC).Close()
		}
	}
}

func (n *NetworkServerGRPC) NetworkSync(data *NetworkSyncData) {
	sd := ParseSyncDataGRPC(data)
	for _, c := range n.groupConnCopy(data.Group) {
		sd.Group = c.session.Group()
		c.Send(sd)
	}
}

func (n *NetworkServerGRPC) Close() (err error) {
	for _, c := range n.groupConnCopy("*") {
		c.Close()
	}
	return
}

func (n *NetworkServerGRPC) RemoteCall(ctx context.Context, arg *grpc.CallArg) (result *grpc.CallResult, err error) {
	session := NewNetworkSessionFromGRPC(ctx)
	conn := n.keepSession(session)
	ret, xerr := n.callback.OnNetworkCall(conn, &NetworkCallArg{
		UUID: arg.Id.Uuid,
		CID:  arg.Cid,
		Name: arg.Name,
		Arg:  arg.Arg,
	})

	if xerr != nil {
		result = &grpc.CallResult{
			Id:    arg.Id,
			Cid:   arg.Cid,
			Name:  arg.Name,
			Error: xerr.Error(),
		}
	} else {
		result = &grpc.CallResult{
			Id:     &grpc.RequestID{Uuid: ret.UUID},
			Cid:    ret.CID,
			Name:   ret.Name,
			Result: ret.Result,
		}
	}
	return
}

func (n *NetworkServerGRPC) RemotePing(ctx context.Context, arg *grpc.PingArg) (result *grpc.PingResult, err error) {
	session := NewNetworkSessionFromGRPC(ctx)
	n.keepSession(session)
	result = &grpc.PingResult{
		Id:         arg.Id,
		ServerTime: xtime.Now(),
	}
	return
}

func (n *NetworkServerGRPC) RemoteSync(arg *grpc.SyncArg, stream grpc.Server_RemoteSyncServer) (err error) {
	session := NewNetworkSessionFromGRPC(stream.Context())
	n.keepSession(session)
	conn := NewNetworkSyncStreamGRPC(session, stream)
	n.addStream(conn)
	defer n.cancleStream(conn)
	err = conn.Wait()
	return
}

type NetworkClientGRPC struct {
	*NetworkBaseConnGRPC
	grpc.ServerClient
	connection *ggrpc.ClientConn
	sync       grpc.Server_RemoteSyncClient
	callback   NetworkCallback
	waiter     sync.WaitGroup
}

func NewNetworkClientGRPC(connection *ggrpc.ClientConn, callback NetworkCallback) (client *NetworkClientGRPC) {
	client = &NetworkClientGRPC{
		NetworkBaseConnGRPC: &NetworkBaseConnGRPC{
			session:  Network.NetworkSession,
			state:    NetworkStateReady,
			isServer: true,
			isClient: true,
		},
		connection: connection, callback: callback,
		waiter: sync.WaitGroup{},
	}
	client.ServerClient = grpc.NewServerClient(client.connection)
	return
}

func (n *NetworkClientGRPC) withNetworkContext() (ctx context.Context, cancel func()) {
	ctx, cancel = context.WithTimeout(NewOutgoingContext(context.Background(), Network.NetworkSession), Network.Timeout)
	return
}

func (n *NetworkClientGRPC) loopSync() (err error) {
	defer func() {
		if perr := recover(); perr != nil {
			Errorf("[GRPC] loop client sync painc with %v, callstack is \n%v", perr, xdebug.CallStack())
		}
		n.waiter.Done()
	}()
	n.callback.OnNetworkState(NetworkConnectionSet{n.ID(): n}, n, NetworkStateReady, nil)
	for {
		sd, xerr := n.sync.Recv()
		if xerr != nil {
			err = xerr
			break
		}
		n.callback.OnNetworkSync(n, ParseNetworkSyncDataGRPC(sd))
	}
	n.callback.OnNetworkState(NetworkConnectionSet{n.ID(): n}, n, NetworkStateClosed, err)
	return
}

func (n *NetworkClientGRPC) Start() (err error) {
	ctx := NewOutgoingContext(context.Background(), Network.NetworkSession)
	n.sync, err = n.RemoteSync(ctx, &grpc.SyncArg{
		Id: &grpc.RequestID{Uuid: uuid.New()},
	})
	if err != nil {
		return
	}
	n.waiter.Add(1)
	go n.loopSync()
	return
}

func (n *NetworkClientGRPC) Stop() (err error) {
	n.Close()
	n.waiter.Wait()
	return
}

func (n *NetworkClientGRPC) Ping() (speed time.Duration, err error) {
	ctx, cancel := n.withNetworkContext()
	defer cancel()
	startTime := time.Now()
	_, err = n.RemotePing(ctx, &grpc.PingArg{Id: &grpc.RequestID{Uuid: uuid.New()}})
	speed = time.Since(startTime)
	return
}

func (n *NetworkClientGRPC) NetworkSync(data *NetworkSyncData) {
}

func (n *NetworkClientGRPC) NetworkCall(arg *NetworkCallArg) (ret *NetworkCallResult, err error) {
	ctx, cancel := n.withNetworkContext()
	defer cancel()
	res, err := n.RemoteCall(ctx, &grpc.CallArg{
		Id:   &grpc.RequestID{Uuid: arg.UUID},
		Cid:  arg.CID,
		Name: arg.Name,
		Arg:  arg.Arg,
	})
	if err != nil {
		return
	}
	if len(res.Error) > 0 {
		err = fmt.Errorf("%v", res.Error)
		return
	}
	ret = &NetworkCallResult{
		UUID:   res.Id.Uuid,
		CID:    res.Cid,
		Name:   res.Name,
		Result: res.Result,
	}
	return
}

func (n *NetworkClientGRPC) Close() (err error) {
	err = n.connection.Close()
	return
}

type NetworkWebsocketResponseWriterGRPC struct {
	http.ResponseWriter
}

func (n *NetworkWebsocketResponseWriterGRPC) Hijack() (conn net.Conn, buffer *bufio.ReadWriter, err error) {
	c := &NetworkWebsocketResponseConnGRPC{}
	c.Conn, buffer, err = n.ResponseWriter.(http.Hijacker).Hijack()
	conn = c
	return
}

type NetworkWebsocketResponseConnGRPC struct {
	net.Conn
	accepted bool
}

func (n *NetworkWebsocketResponseConnGRPC) Close() (err error) {
	if n.accepted {
		err = n.Conn.Close()
	} else {
		n.accepted = true
	}
	return
}

type NetworkWebsocketConnGRPC struct {
	*websocket.Conn
}

func (n *NetworkWebsocketConnGRPC) Read(p []byte) (s int, err error) {
	codec := &websocket.Codec{
		Unmarshal: func(data []byte, payloadType byte, v interface{}) (err error) {
			switch payloadType {
			case websocket.TextFrame: //for web browser
				for i, d := range strings.Split(string(data), ",") {
					v, xerr := strconv.ParseInt(d, 10, 8)
					if xerr != nil {
						err = xerr
						break
					}
					p[i] = byte(v)
					s++
				}
			default:
				s = copy(p, data)
			}
			return
		},
	}
	err = codec.Receive(n.Conn, nil)
	return
}

func (n *NetworkWebsocketConnGRPC) Write(p []byte) (s int, err error) {
	codec := &websocket.Codec{
		Marshal: func(v interface{}) (data []byte, payloadType byte, err error) {
			s = len(p)
			data = p
			payloadType = websocket.BinaryFrame
			return
		},
	}
	err = codec.Send(n.Conn, nil)
	return
}

type NetworkWebsocketServerGRPC struct {
	Websocket *websocket.Server
	accepter  chan net.Conn
	closed    bool
}

func NewNetworkWebsocketServerGRPC() (server *NetworkWebsocketServerGRPC) {
	server = &NetworkWebsocketServerGRPC{
		Websocket: &websocket.Server{},
		accepter:  make(chan net.Conn, 8),
	}
	server.Websocket.Handler = server.handleWS
	return
}

func (n *NetworkWebsocketServerGRPC) ServeHTTP(res http.ResponseWriter, req *http.Request) {
	n.Websocket.ServeHTTP(&NetworkWebsocketResponseWriterGRPC{ResponseWriter: res}, req)
}

func (n *NetworkWebsocketServerGRPC) handleWS(c *websocket.Conn) {
	n.accepter <- &NetworkWebsocketConnGRPC{Conn: c}
}

func (n *NetworkWebsocketServerGRPC) Accept() (conn net.Conn, err error) {
	n.closed = false
	c := <-n.accepter
	if c == nil {
		err = fmt.Errorf("closed")
		return
	}
	conn = c
	return
}

func (n *NetworkWebsocketServerGRPC) Close() (err error) {
	if n.closed {
		err = fmt.Errorf("closed")
		return
	}
	n.closed = true
	n.accepter <- nil
	return
}

func (n *NetworkWebsocketServerGRPC) Addr() net.Addr {
	return n
}

func (n *NetworkWebsocketServerGRPC) Network() string {
	return "WebsocketTransport"
}

func (n *NetworkWebsocketServerGRPC) String() string {
	return "WebsocketTransport"
}

type NetworkTransportGRPC struct {
	GrpcOn       bool
	WebOn        bool
	GrpcAddress  *url.URL
	GrpcOpts     []ggrpc.DialOption
	WebAddress   *url.URL
	Client       *NetworkClientGRPC
	Server       *NetworkServerGRPC
	GrpcServer   *ggrpc.Server
	WebServer    *http.Server
	GrpcListener net.Listener
	WebListener  net.Listener
	ServerConfig *tls.Config
	ConnConfig   *tls.Config
	WebMux       *http.ServeMux
	Websocket    *NetworkWebsocketServerGRPC
	initial      bool
	running      bool
	exiter       chan int
	waiter       sync.WaitGroup
}

func NewNetworkTransportGRPC() (transport *NetworkTransportGRPC) {
	transport = &NetworkTransportGRPC{
		GrpcOn:   true,
		WebOn:    true,
		GrpcOpts: []ggrpc.DialOption{ggrpc.WithTransportCredentials(insecure.NewCredentials())},
		exiter:   make(chan int, 8),
		waiter:   sync.WaitGroup{},
	}
	transport.GrpcAddress, _ = url.Parse("grpc://127.0.0.1:50051/")
	transport.WebAddress, _ = url.Parse("ws://127.0.0.1:50052/")
	transport.Server = NewNetworkServerGRPC(Network)
	transport.GrpcServer = ggrpc.NewServer()
	transport.WebMux = http.NewServeMux()
	transport.Websocket = NewNetworkWebsocketServerGRPC()
	transport.WebServer = &http.Server{Handler: transport.Websocket}
	grpc.RegisterServerServer(transport.GrpcServer, transport.Server)
	return
}

func (n *NetworkTransportGRPC) serveGRPC(ln net.Listener) {
	defer n.waiter.Done()
	Infof("[GRPC] start grpc server on %v", ln.Addr())
	err := n.GrpcServer.Serve(ln)
	Infof("[GRPC] grpc server on %v is stopped by %v", ln.Addr(), err)
}

func (n *NetworkTransportGRPC) serveWeb(ln net.Listener) {
	defer n.waiter.Done()
	Infof("[GRPC] start web server on %v", ln.Addr())
	err := n.WebServer.Serve(ln)
	Infof("[GRPC] web server on %v is stopped by %v", ln.Addr(), err)
}

func (n *NetworkTransportGRPC) connect() (err error) {
	if n.Client != nil {
		n.Client.Close()
	}
	opts := n.GrpcOpts
	if !n.GrpcOn {
		opts = append(opts, ggrpc.WithContextDialer(func(ctx context.Context, s string) (conn net.Conn, err error) {
			originURL := n.WebAddress.String()
			originURL = strings.ReplaceAll(originURL, "ws://", "http://")
			originURL = strings.ReplaceAll(originURL, "wss://", "https://")
			origin, _ := url.Parse(originURL)
			config := &websocket.Config{
				Location:  n.WebAddress,
				Origin:    origin,
				TlsConfig: n.ConnConfig,
				Version:   websocket.ProtocolVersionHybi13,
			}
			wcon, err := websocket.DialConfig(config)
			conn = &NetworkWebsocketConnGRPC{Conn: wcon}
			return
		}))
	}
	if n.ConnConfig != nil {
		opts = append(opts, ggrpc.WithTransportCredentials(credentials.NewTLS(n.ConnConfig)))
	}
	ctx, cancel := context.WithTimeout(NewOutgoingContext(context.Background(), Network.NetworkSession), Network.Timeout)
	defer cancel()
	connection, xerr := ggrpc.DialContext(ctx, n.GrpcAddress.Host, opts...)
	if xerr != nil {
		err = xerr
		return
	}
	n.Client = NewNetworkClientGRPC(connection, Network)
	err = n.Client.Start()
	return
}

func (n *NetworkTransportGRPC) loopKeep() {
	defer n.waiter.Done()
	Infof("[GRPC] keepalive task is starting by %v", Network.Keepalive)
	ticker := time.NewTicker(Network.Keepalive)
	running := true
	for running {
		select {
		case <-ticker.C:
			n.procKeep()
		case <-n.exiter:
			running = false
		}
	}
	Infof("[GRPC] keepalive task is stopped")
}

func (n *NetworkTransportGRPC) procKeep() {
	defer func() {
		if perr := recover(); perr != nil {
			Errorf("[GRPC] proc keep painc with %v, callstack is \n%v", perr, xdebug.CallStack())
		}
	}()
	if Network.IsServer && n.running {
		n.Server.timeout(Network.Keepalive * 2)
	}
	if Network.IsClient && n.running {
		speed, err := n.Client.Ping()
		if err != nil {
			Warnf("[GRPC] ping to server error %v", err)
			n.connect()
		} else {
			Network.PingSpeed = speed
			Network.OnNetworkPing(n.Client, speed)
		}
	}
}

func (n *NetworkTransportGRPC) createListener(host string) (ln net.Listener, err error) {
	if n.ServerConfig == nil {
		ln, err = net.Listen("tcp", host)
	} else {
		ln, err = tls.Listen("tcp", host, n.ServerConfig)
	}
	return
}

func (n *NetworkTransportGRPC) Start() (err error) {
	if !n.initial {
		n.WebMux.Handle(n.WebAddress.Path, n.Websocket)
		n.initial = true
	}
	if Network.IsServer {
		if n.GrpcOn {
			n.GrpcListener, err = n.createListener(n.GrpcAddress.Host)
			if err != nil {
				return
			}
			n.waiter.Add(1)
			go n.serveGRPC(n.GrpcListener)
			n.running = true
		}
		if n.WebOn {
			n.WebListener, err = n.createListener(n.WebAddress.Host)
			if err != nil {
				return
			}
			n.waiter.Add(1)
			go n.serveWeb(n.WebListener)
			n.running = true
		}
		n.waiter.Add(1)
		go n.serveGRPC(n.Websocket)
	}
	if Network.IsClient {
		if n.GrpcOn || n.WebOn {
			err = n.connect()
			n.running = err == nil
		} else {
			err = fmt.Errorf("grpc or web is required")
		}
		if err != nil {
			return
		}
	}
	if Network.Keepalive > 0 {
		n.waiter.Add(1)
		go n.loopKeep()
	}
	return
}

func (n *NetworkTransportGRPC) Stop() (err error) {
	n.exiter <- 1
	if n.GrpcListener != nil {
		n.GrpcListener.Close()
		n.GrpcListener = nil
	}
	if n.WebListener != nil {
		n.WebListener.Close()
		n.WebListener = nil
	}
	if n.Client != nil {
		n.Client.Stop()
		n.Client = nil
	}
	n.Server.Close()
	n.Websocket.Close()
	n.waiter.Wait()
	return
}

func (n *NetworkTransportGRPC) NetworkSync(data *NetworkSyncData) {
	if Network.IsServer {
		n.Server.NetworkSync(data)
	}
}

func (n *NetworkTransportGRPC) NetworkCall(arg *NetworkCallArg) (ret *NetworkCallResult, err error) {
	if !Network.IsClient || n.Client == nil {
		err = fmt.Errorf("not client or not connect")
		return
	}
	ret, err = n.Client.NetworkCall(arg)
	return
}
