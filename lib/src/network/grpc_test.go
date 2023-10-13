package network

import (
	"context"
	"fmt"
	"net/url"
	"testing"
	"time"

	"github.com/centny/flame_network/lib/src/network/grpc"
	"github.com/codingeasygo/util/xdebug"
	"github.com/codingeasygo/util/xmap"
	ggrpc "google.golang.org/grpc"
)

func TestGRPC(t *testing.T) {
	tester := xdebug.CaseTester{
		0: 1,
		3: 1,
	}
	Network.IsServer = true
	Network.IsClient = true
	Network.SetGroup("test")
	Network.Transport = NewNetworkTransportGRPC()
	if tester.Run() { //NetworkManager.sync
		err := Network.Start()
		if err != nil {
			t.Error(err)
			return
		}
		time.Sleep(500 * time.Millisecond)
		nc := NewTestNetworkComponent()

		//
		Network.Sync("*")

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

		fmt.Println("--->")
		Network.Stop()
	}
	if tester.Run() { //NetworkManager.keep
		Network.Keepalive = 100 * time.Millisecond
		err := Network.Start()
		if err != nil {
			t.Error(err)
			return
		}
		time.Sleep(200 * time.Millisecond)
		transport := Network.Transport.(*NetworkTransportGRPC)
		transport.Server.timeout(10 * time.Millisecond)

		Network.Stop()
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
		NewOutgoingContext(context.Background(), NewNetworkSession(xmap.NewSafeByBase(s)))
	}
	if tester.Run() { //cover 2
		sd := &grpc.SyncData{
			Id: &grpc.RequestID{},
			Components: []*grpc.SyncDataComponent{
				{
					Props: "xxx",
				},
				{
					Props: "{}",
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

		c1 := NewNetworkSyncStreamGRPC(nil, nil)
		c1.Close()
		c1.Close()
	}
	if tester.Run() { //cover 4
		err := Network.Start()
		if err != nil {
			t.Error(err)
			return
		}
		transport := Network.Transport.(*NetworkTransportGRPC)
		client := transport.Client
		Network.Stop()

		client.NetworkCall(&NetworkCallArg{})

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
