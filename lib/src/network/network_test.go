package network

import (
	"fmt"
	"net/http"
	_ "net/http/pprof"
	"testing"
	"time"

	"github.com/codingeasygo/util/xdebug"
	"github.com/codingeasygo/util/xmap"
)

func init() {
	go http.ListenAndServe(":6062", nil)
}

type TestNetworkCallArg struct {
	Value int `json:"value"`
}

type TestNetworkCallRet struct {
	Value int `json:"value"`
}

type TestNetworkValue struct {
	User string
}

func (t *TestNetworkValue) Access(session NetworkSession) bool {
	return t.User == session.User()
}

type TestNetworkComponent struct {
	*NetworkComponent
}

func NewTestNetworkComponent() (c *TestNetworkComponent) {
	c = &TestNetworkComponent{
		NetworkComponent: NewNetworkComponent("test", "test", "123"),
	}
	c.Refer = c
	c.OnPropUpdate["*"] = c.onPropAll
	c.OnPropUpdate["p0"] = c.onPropAll
	c.SetValue("p0", 123)
	c.SetValue("p1", "abc")
	c.SetValue("p2", &TestNetworkValue{})
	c.RegisterNetworkProp()
	c.RegisterNetworkTrigger("t0", c.onTrigger0)
	c.RegisterNetworkTrigger("t1", c.onTrigger1)
	c.RegisterNetworkTrigger("t2", c.onTrigger2)
	c.RegisterNetworkCall("c0", c.onCall0)
	c.RegisterNetworkCall("c1", c.onCall1)
	c.RegisterNetworkCall("c2", c.onCall2)
	c.RegisterNetworkCall("c3", c.onCall3)
	c.RegisterNetworkCall("e0", c.onErr0)
	c.RegisterNetworkCall("e1", c.onErr1)
	c.RegisterNetworkEvent("test", c)
	c.OnNetworkRemove = c.Unregister
	return
}

func (t *TestNetworkComponent) onPropAll(key string, value interface{}) {
	fmt.Printf("on prop %v=>%v\n", key, value)
}

func (t *TestNetworkComponent) onTrigger0(v float64) {
	fmt.Printf("on trigger =>%v\n", v)
}

func (t *TestNetworkComponent) onTrigger1(n string, v string) {
	fmt.Printf("on trigger %v=>%v\n", n, v)
}

func (t *TestNetworkComponent) onTrigger2(n string, v *TestNetworkValue) {
	fmt.Printf("on trigger %v=>%v\n", n, v)
}

func (t *TestNetworkComponent) onCall0(ctx NetworkSession, uuid string) (ret string, err error) {
	ret = "test"
	fmt.Printf("onCall0 =>%v,%v\n", ret, err)
	return
}

func (t *TestNetworkComponent) onCall1(ctx NetworkSession, uuid string, arg string) (err error) {
	if arg != "test" {
		err = fmt.Errorf("not test")
	}
	fmt.Printf("onCall1 %v=>%v,%v\n", arg, "", err)
	return
}

func (t *TestNetworkComponent) onCall2(ctx NetworkSession, uuid string, arg string) (ret string, err error) {
	ret = arg
	fmt.Printf("onCall3 %v=>%v,%v\n", arg, ret, err)
	return
}

func (t *TestNetworkComponent) onCall3(ctx NetworkSession, uuid string, arg *TestNetworkCallArg) (ret *TestNetworkCallRet, err error) {
	ret = &TestNetworkCallRet{Value: arg.Value}
	fmt.Printf("onCall3 %v=>%v,%v\n", arg, ret, err)
	return
}

func (t *TestNetworkComponent) onErr0(ctx NetworkSession, uuid string) (err error) {
	err = fmt.Errorf("error")
	return
}

func (t *TestNetworkComponent) onErr1(ctx NetworkSession, uuid string, v func()) (err error) {
	err = fmt.Errorf("error")
	return
}

func (t *TestNetworkComponent) OnNetworkState(all NetworkConnectionSet, conn NetworkConnection, state NetworkState, info interface{}) {
}

func (t *TestNetworkComponent) OnNetworkPing(conn NetworkConnection, ping time.Duration) {
}

func (t *TestNetworkComponent) Unregister() {
	t.Clear()
	t.UnregisterNetworkProp()
	t.UnregisterNetworkTrigger("t0")
	t.UnregisterNetworkCall("c0")
	t.ClearNetworkTrigger()
	t.ClearNetworkCall()
	t.UnregisterNetworkEvent(t)
}

type TestNetworkConnection struct {
	session NetworkSession
	state   NetworkState
	server  bool
	client  bool
}

func (t *TestNetworkConnection) ID() string {
	return "c0"
}
func (t *TestNetworkConnection) Session() NetworkSession {
	return t.session
}
func (t *TestNetworkConnection) State() NetworkState {
	return t.state
}
func (t *TestNetworkConnection) IsServer() bool {
	return t.server
}
func (t *TestNetworkConnection) IsClient() bool {
	return t.client
}
func (t *TestNetworkConnection) NetworkSync(data *NetworkSyncData) {

}

type TestNetworkTransport struct {
	callback NetworkCallback
	conn     *TestNetworkConnection
}

func (t *TestNetworkTransport) Start() (err error) {
	t.conn = &TestNetworkConnection{
		client:  Network.IsClient,
		server:  Network.IsServer,
		session: Network.NetworkSession,
	}
	t.callback = Network
	// go func() {
	// 	t.callback.OnNetworkState(NetworkConnectionSet{t.conn.ID(): t.conn}, t.conn, NetworkStateReady, nil)
	// 	Network.OnNetworkPing(t.conn, time.Second)
	// }()
	return
}
func (t *TestNetworkTransport) Stop() (err error) {
	// go func() {
	// 	t.callback.OnNetworkState(NetworkConnectionSet{t.conn.ID(): t.conn}, t.conn, NetworkStateClosed, nil)
	// }()
	return
}
func (t *TestNetworkTransport) IsReady() (ready bool) {
	ready = true
	return
}
func (t *TestNetworkTransport) Ready() (err error) {
	return
}
func (t *TestNetworkTransport) NetworkSync(data *NetworkSyncData) {
	t.callback.OnNetworkSync(t.conn, data)
}
func (t *TestNetworkTransport) NetworkCall(arg *NetworkCallArg) (ret *NetworkCallResult, err error) {
	ret, err = t.callback.OnNetworkCall(t.conn, arg)
	return
}

func TestNetwork(t *testing.T) {
	tester := xdebug.CaseTester{
		0: 1,
		4: 1,
	}
	Network.IsServer = true
	Network.IsClient = true
	Network.SetGroup("test")
	Network.Transport = &TestNetworkTransport{}
	Network.Start()
	ComponentHub.OnAdd = func(c *NetworkComponent) {}
	ComponentHub.OnRemove = func(c *NetworkComponent) {}
	defer Network.Stop()
	if tester.Run() {
		session := NewDefaultNetworkSessionBySafeM()
		session.SetKey("123")
		session.SetUser("u1")
		session.SetGroup("g1")
		if session.Key() != "123" || session.User() != "u1" || session.Group() != "g1" {
			t.Error("error")
			return
		}
	}
	if tester.Run() { //NetworkManager.sync
		nc := NewTestNetworkComponent()
		Network.Sync("*")
		Network.Sync("*")
		nc.Unregister()
	}
	if tester.Run() { //NetworkComponent.sync
		nc := NewTestNetworkComponent()

		cs := ComponentHub.SyncSend("*", false)
		if len(cs) != 1 {
			t.Errorf("cs is %v", len(cs))
			return
		}
		ComponentHub.SyncRecv("*", cs, false)

		cs = ComponentHub.SyncSend("*", false)
		if len(cs) != 0 {
			t.Errorf("cs is %v", len(cs))
			return
		}

		nc.SetValue("a", "123")
		cs = ComponentHub.SyncSend("*", false)
		if len(cs) != 1 {
			t.Errorf("cs is %v", len(cs))
			return
		}

		cs = ComponentHub.SyncSend("*", true)
		if len(cs) != 1 {
			t.Errorf("cs is %v", len(cs))
			return
		}

		nc.Removed = true
		cs = ComponentHub.SyncSend("*", true)
		if len(cs) != 1 || !cs[0].Removed {
			t.Errorf("cs is %v", len(cs))
			return
		}

		nc.Unregister()

		cs = ComponentHub.SyncSend("*", true)
		if len(cs) != 0 {
			t.Errorf("cs is %v", len(cs))
			return
		}

		nc = NewTestNetworkComponent()
		ComponentHub.SyncRecv("*", []*NetworkSyncDataComponent{
			{
				Factory: nc.Factory,
				CID:     nc.CID,
				Removed: true,
			},
		}, false)
		cs = ComponentHub.SyncSend("*", true)
		if len(cs) != 0 {
			t.Errorf("cs is %v", len(cs))
			return
		}
		nc.Unregister()

		nc = NewTestNetworkComponent()
		ComponentHub.SyncRecv("*", nil, true)
		cs = ComponentHub.SyncSend("*", true)
		if len(cs) != 0 {
			t.Errorf("cs is %v", len(cs))
			return
		}
		nc.Unregister()
	}
	if tester.Run() { //NetworkComponent.trigger
		nc := NewTestNetworkComponent()
		err := nc.NetworkTrigger("t0", 1.1)
		if err != nil {
			t.Error(err)
			return
		}
		err = nc.NetworkTrigger("t1", "abc")
		if err != nil {
			t.Error(err)
			return
		}
		err = nc.NetworkTrigger("t2", &TestNetworkValue{})
		if err != nil {
			t.Error(err)
			return
		}

		cs := NewNetworkSyncDataBySyncSend("*", false)
		if len(cs.Components) != 1 {
			t.Errorf("cs is %v", len(cs.Components))
			return
		}
		cs = cs.Encode(Network.NetworkSession)
		ComponentHub.SyncRecv("*", cs.Components, false)

		nc.RecvNetworkTrigger(xmap.M{"none": "123"})
		nc.RecvNetworkTrigger(xmap.M{"t0": []interface{}{}})
		nc.RecvNetworkTrigger(xmap.M{"t0": []interface{}{"x"}})

		if err = nc.RegisterNetworkTrigger("none", func() {}); err == nil {
			t.Error("error")
			return
		}
		if err = nc.RegisterNetworkTrigger("t0", func(int) {}); err == nil {
			t.Error("error")
			return
		}
		if err = nc.NetworkTrigger("none", 1); err == nil {
			t.Error("error")
			return
		}

		nc.Unregister()
	}
	if tester.Run() { //NetworkComponent.create
		err := ComponentHub.SyncRecv("*", []*NetworkSyncDataComponent{
			{
				Factory: "test",
				CID:     "123",
				Props:   xmap.M{"a": 123},
			},
		}, false)
		if err == nil {
			t.Error(err)
			return
		}
		ComponentHub.RegisterFactory("*", "xxx", func(key, group, cid string) (*NetworkComponent, error) {
			nc := NewTestNetworkComponent()
			return nc.NetworkComponent, nil
		})
		ComponentHub.SyncRecv("*", []*NetworkSyncDataComponent{
			{
				Factory: "test",
				CID:     "123",
				Props:   xmap.M{"a": 123},
			},
		}, false)
		cs := ComponentHub.SyncSend("*", false)
		if len(cs) != 1 {
			t.Errorf("cs is %v", len(cs))
			return
		}
		nc := ComponentHub.FindComponent("123")
		if nc == nil || nc.Int64Def(0, "a") != 123 {
			t.Error("error")
		}
		ComponentHub.SyncRecv("*", []*NetworkSyncDataComponent{
			{
				Factory: nc.Factory,
				CID:     nc.CID,
				Removed: true,
			},
		}, false)
		cs = ComponentHub.SyncSend("*", false)
		if len(cs) != 0 {
			t.Errorf("cs is %v", len(cs))
			return
		}

		nc.Refer.(*TestNetworkComponent).Unregister()

		ComponentHub.RegisterFactory("error-0", "", func(key, group, cid string) (*NetworkComponent, error) {
			return nil, fmt.Errorf("error")
		})
		ComponentHub.CreateComponent("error-0", "", "1111")
	}
	if tester.Run() { //NetworkComponent.call
		nc := NewTestNetworkComponent()

		var ret0 string
		if err := nc.NetworkCall("c0", nil, &ret0); err != nil || ret0 != "test" {
			t.Errorf("err:%v,ret:%v", err, ret0)
			return
		}

		if err := nc.NetworkCall("c1", "test", nil); err != nil {
			t.Errorf("err:%v", err)
			return
		}

		var ret2 string
		if err := nc.NetworkCall("c2", "test", &ret2); err != nil || ret2 != "test" {
			t.Errorf("err:%v", err)
			return
		}

		var ret3 TestNetworkCallRet
		if err := nc.NetworkCall("c3", &TestNetworkCallArg{Value: 123}, &ret3); err != nil || ret3.Value != 123 {
			t.Errorf("err:%v", err)
			return
		}

		if err := nc.NetworkCall("none", nil, nil); err == nil {
			t.Errorf("err:%v", err)
			return
		}

		if err := nc.NetworkCall("e0", nil, nil); err == nil {
			t.Errorf("err:%v", err)
			return
		}

		if err := nc.NetworkCall("e1", "abc", nil); err == nil {
			t.Errorf("err:%v", err)
			return
		}

		if _, err := Network.NetworkCall(&NetworkCallArg{}); err == nil {
			t.Errorf("err:%v", err)
			return
		}

		nc.Unregister()
	}
	if tester.Run() { //NetworkComponent.event
		nc := NewTestNetworkComponent()
		EventHub.OnNetworkPing(Network.Transport.(*TestNetworkTransport).conn, time.Second)
		nc.Unregister()
	}
	if tester.Run() {
		m := NewSyncMap()
		m.SetValue("a", 123)
		m.Exist("a")
		m.Delete("a")
	}
	if tester.Run() { //cover
		arg := &NetworkCallArg{}
		fmt.Printf("arg--->%v\n", arg)
		ret := &NetworkCallResult{}
		fmt.Printf("ret--->%v\n", ret)

		nc := NewTestNetworkComponent()
		nc.IsOwner()
		nc.IsServer()
		nc.IsClient()
		nc.RegisterNetworkCall("c0", func() {})
		nc.Unregister()

		nc.SafeM = nil
		nc.CallNetworkCall(nil, &NetworkCallArg{})
	}
}
