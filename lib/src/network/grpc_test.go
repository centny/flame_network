package network

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/centny/flame_network/lib/src/network/grpc"
	"github.com/codingeasygo/util/xcrypto"
	"github.com/codingeasygo/util/xdebug"
	"github.com/codingeasygo/util/xmap"
	"go.uber.org/zap/zapcore"
	"golang.org/x/net/websocket"
	ggrpc "google.golang.org/grpc"
)

type TestNetworkEvent struct {
	conn   NetworkConnection
	waiter chan int
}

func NewTestNetworkEvent() (event *TestNetworkEvent) {
	event = &TestNetworkEvent{
		waiter: make(chan int, 1),
	}
	EventHub.RegisterNetworkEvent("*", event)
	return
}

func (t *TestNetworkEvent) OnNetworkState(all NetworkConnectionSet, conn NetworkConnection, state NetworkState, info interface{}) {
	t.conn = conn
	select {
	case t.waiter <- 1:
	default:
	}
}

func (t *TestNetworkEvent) OnNetworkPing(conn NetworkConnection, ping time.Duration) {
}

func (t *TestNetworkEvent) OnNetworkDataSynced(conn NetworkConnection, data *NetworkSyncData) {
}

func TestGRPC(t *testing.T) {
	SetLevel(zapcore.DebugLevel)
	tester := xdebug.CaseTester{
		0: 1,
		1: 1,
	}
	newTestTransport := func() *NetworkTransportGRPC {
		n := NewNetworkTransportGRPC()
		n.GrpcAddress, _ = url.Parse("grpc://127.0.0.1:50060")
		n.WebAddress, _ = url.Parse("ws://127.0.0.1:50061")
		return n
	}
	var connEvent *TestNetworkEvent
	resetNetwork := func() {
		Network.Verbose = true
		Network.IsServer = true
		Network.IsClient = true
		Network.SetGroup("test")
		Network.SetKey("test")
		Network.Transport = newTestTransport()
		connEvent = NewTestNetworkEvent()
	}
	if tester.Run() { //NetworkManager.sync
		resetNetwork()
		err := Network.Start()
		if err != nil {
			t.Error(err)
			return
		}
		err = Network.Ready()
		if err != nil {
			t.Error(err)
			return
		}
		<-connEvent.waiter
		if connEvent.conn == nil {
			t.Error("error")
			return
		}
		nc := NewTestNetworkComponent()

		//
		time.Sleep(500 * time.Millisecond)
		Network.Sync("*", nil)
		time.Sleep(500 * time.Millisecond)
		nc.SetValue("test", 1)
		Network.Sync("*", connEvent.conn)
		//

		var ret0 string
		if err := nc.NetworkCall("c0", nil, &ret0); err != nil || ret0 != "test" {
			t.Errorf("err:%v,ret:%v", err, ret0)
			return
		}
		if err := nc.NetworkCall("e0", nil, nil); err == nil {
			t.Errorf("err:%v", err)
			return
		}

		time.Sleep(300 * time.Millisecond)

		nc.Unregister()

		Network.Pause()
		Network.Stop()
	}
	if tester.Run() { //NetworkManager.close
		resetNetwork()
		err := Network.Start()
		if err != nil {
			t.Error(err)
			return
		}
		err = Network.Ready()
		if err != nil {
			t.Error(err)
			return
		}
		<-connEvent.waiter
		if connEvent.conn == nil {
			t.Error("error")
			return
		}
		Network.Pause()
		Network.Stop()
	}
	if tester.Run() { //NetworkManager.keep
		resetNetwork()
		Network.Keepalive = 100 * time.Millisecond
		err := Network.Start()
		if err != nil {
			t.Error(err)
			return
		}
		err = Network.Ready()
		if err != nil {
			t.Error(err)
			return
		}
		transport := Network.Transport.(*NetworkTransportGRPC)
		time.Sleep(200 * time.Millisecond)
		transport.Server.timeout(10 * time.Millisecond)
		time.Sleep(200 * time.Millisecond)
		transport.Server.timeout(10 * time.Millisecond)

		Network.Stop()
	}
	if tester.Run() { //NetworkManager.web
		resetNetwork()
		Network.Transport.(*NetworkTransportGRPC).GrpcOn = false
		Network.Transport.(*NetworkTransportGRPC).WebOn = true
		err := Network.Start()
		if err != nil {
			t.Error(err)
			return
		}
		err = Network.Ready()
		if err != nil {
			t.Error(err)
			return
		}
		nc := NewTestNetworkComponent()

		Network.Sync("*", nil)

		var ret0 string
		if err := nc.NetworkCall("c0", nil, &ret0); err != nil || ret0 != "test" {
			t.Errorf("err:%v,ret:%v", err, ret0)
			return
		}
		if err := nc.NetworkCall("e0", nil, nil); err == nil {
			t.Errorf("err:%v", err)
			return
		}

		nc.Unregister()

		Network.Stop()

		err = nc.NetworkCall("c0", nil, &ret0)
		if err == nil {
			t.Errorf("err:%v,ret:%v", err, ret0)
			return
		}
		fmt.Printf("stopped error is %v\n", err)

		Network.Transport.(*NetworkTransportGRPC).GrpcOn = true
		Network.Transport.(*NetworkTransportGRPC).WebOn = true

		n := newTestTransport()
		n.GrpcOn = false
		n.WebOn = true
		for i := 0; i < 3; i++ {
			err := n.Start()
			if err != nil {
				t.Error(err)
				return
			}
			n.Stop()
		}

		ts := httptest.NewServer(websocket.Handler(func(c *websocket.Conn) {
			conn := &NetworkWebsocketConnGRPC{Conn: c}
			io.Copy(conn, conn)
		}))
		conn, _ := websocket.Dial(strings.ReplaceAll(ts.URL, "http://", "ws://"), "", ts.URL)
		fmt.Fprintf(conn, "1,2,3")
		conn.Read(make([]byte, 1024))
		fmt.Fprintf(conn, "a,b,c")
		conn.Read(make([]byte, 1024))
		conn.Close()

		w := NewNetworkWebsocketServerGRPC()
		fmt.Printf("-->%v,%v\n", w.Network(), w)
	}
	if tester.Run() { //NetworkManager.tls
		xcrypto.GenerateWebServerClient("test.loc", "test.loc", "test.loc", "127.0.0.1", 2048)
		_, _, rootCertPEM, rootKeyPEM, _, severCertPEM, serverKeyPEM, _, clientCertPEM, clientKeyPEM, _ := xcrypto.GenerateWebServerClient("test.loc", "test.loc", "test.loc", "127.0.0.1", 2048)
		os.WriteFile("ca.pem", rootCertPEM, os.ModePerm)
		os.WriteFile("ca.key", rootKeyPEM, os.ModePerm)
		os.WriteFile("server.pem", severCertPEM, os.ModePerm)
		os.WriteFile("server.key", serverKeyPEM, os.ModePerm)
		os.WriteFile("client.pem", clientCertPEM, os.ModePerm)
		os.WriteFile("client.key", clientKeyPEM, os.ModePerm)
		cer, err := tls.LoadX509KeyPair("server.pem", "server.key")
		if err != nil {
			t.Error(err)
			return
		}
		n := newTestTransport()
		n.ServerConfig = &tls.Config{Certificates: []tls.Certificate{cer}}
		n.ConnConfig = &tls.Config{InsecureSkipVerify: true}
		err = n.Start()
		if err != nil {
			t.Error(err)
			return
		}
		n.Stop()
	}
	if tester.Run() { //NetworkManager.ready
		resetNetwork()
		err := Network.Ready()
		if err == nil {
			t.Error("error")
			return
		}
		err = Network.Start()
		if err != nil {
			t.Error(err)
			return
		}
		if Network.IsReady() {
			t.Error("error")
			return
		}
		err = Network.Ready()
		if err != nil {
			t.Error(err)
			return
		}
		if !Network.IsReady() {
			t.Error("error")
			return
		}
		err = Network.Ready()
		if err == nil {
			t.Error("error")
			return
		}
		Network.Stop()
		//
		Network.IsServer = true
		Network.IsClient = false
		transport := newTestTransport()
		err = transport.Start()
		if err != nil {
			t.Error(err)
			return
		}
		transport.Stop()
	}
	if tester.Run() { //cover 1
		s := NetworkSessionValueGRPC{}
		s.SetValue("a", 123)
		s.Exist("a")
		s.ValueVal("a")
		s.ValueVal("none")
		s.Clear()
		s.Length()
		s.Delete("a")
		s.Exist("a")
		NewOutgoingContext(context.Background(), NewDefaultNetworkSessionByMeta(xmap.NewSafeByBase(s)))
	}
	if tester.Run() { //cover 2
		sd := &grpc.SyncData{
			Id: &grpc.RequestID{},
			Components: []*grpc.SyncDataComponent{
				{
					Props: "xxx",
				},
				{
					Props:    "{}",
					Triggers: "xxx",
				},
				{
					Props:    "{}",
					Triggers: "{}",
				},
			},
		}
		data := ParseNetworkSyncDataGRPC(sd)
		data.Components[0].Props["xxx"] = 1.1
		ParseSyncDataGRPC(data)
	}
	if tester.Run() { //cover 3
		conn := &NetworkBaseConnGRPC{}
		conn.ID()
		conn.Session()
		conn.State()
		conn.IsClient()
		conn.IsServer()
		conn.NetworkSync(nil)

		c1 := NewNetworkSyncStreamGRPC(nil, nil)
		c1.Close()
		c1.Close()
	}
	if tester.Run() { //cover 4
		resetNetwork()
		err := Network.Start()
		if err != nil {
			t.Error(err)
			return
		}
		err = Network.Ready()
		if err != nil {
			t.Error(err)
			return
		}
		transport := Network.Transport.(*NetworkTransportGRPC)
		client := transport.Client
		client.Close()
		transport.procKeep()
		Network.Stop()
		client.Stop()
		err = client.Start()
		if err == nil {
			t.Error(err)
			return
		}
		err = Network.Pause()
		if err == nil {
			t.Error(err)
			return
		}

		client.NetworkCall(&NetworkCallArg{})

		transport = newTestTransport()

		transport.GrpcOpts = append(transport.GrpcOpts, ggrpc.WithTransportCredentials(nil))
		err = transport.connect()
		if err == nil {
			t.Error(err)
			return
		}

		transport.GrpcOn = true
		transport.GrpcAddress, _ = url.Parse("grpc://192.113.1.1:10")
		err = transport.Start()
		if err == nil {
			t.Error(err)
			return
		}

		transport.GrpcOn = false
		transport.WebAddress, _ = url.Parse("ws://192.113.1.1:10")
		err = transport.Start()
		if err == nil {
			t.Error(err)
			return
		}

		transport.GrpcOn = false
		transport.WebOn = false
		err = transport.Start()
		if err == nil {
			t.Error(err)
			return
		}

		client.callback = nil
		client.waiter.Add(1)
		client.loopSync()

		transport = NewNetworkTransportGRPC()
		transport.running = true
		transport.procKeep()
	}
}
