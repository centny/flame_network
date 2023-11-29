package lib

import (
	"net/http"
	"net/url"
	"os"
	"runtime"
	"time"

	"github.com/centny/flame_network/lib/src/network"
)

func Main() {
	var err error
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	grpcAddr := os.Getenv("GRPC_ADDR")
	if len(grpcAddr) < 1 {
		grpcAddr = "grpc://0.0.0.0:50051"
	}
	webAddr := os.Getenv("WEB_ADDR")
	if len(webAddr) < 1 {
		webAddr = "ws://0.0.0.0:50052/ws/fire"
	}
	network.Infof("server is starting by grpc:%v,web:%v", grpcAddr, webAddr)
	transport := network.NewNetworkTransportGRPC()
	transport.GrpcAddress, err = url.Parse(grpcAddr)
	if err != nil {
		panic(err)
	}
	transport.WebAddress, err = url.Parse(webAddr)
	if err != nil {
		panic(err)
	}
	transport.WebMux.Handle("/", http.FileServer(http.Dir("www")))
	network.Network.IsServer = true
	network.Network.Transport = transport
	err = network.Network.Start()
	if err != nil {
		panic(err)
	}

	interval := time.Second / 60
	timeStart := time.Now().UnixNano()
	ticker := time.NewTicker(interval)
	exiter := make(chan int, 1)
	game := NewGame()
	for {
		select {
		case <-ticker.C:
			now := time.Now().UnixNano()
			// DT in ms
			delta := float64(now-timeStart) / 1000000000
			timeStart = now
			game.Update(delta)
			network.Network.Sync(game.Group, nil)
		case <-exiter:
			ticker.Stop()
		}
	}
}
