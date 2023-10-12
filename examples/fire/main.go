package main

import (
	"github.com/centny/flame_network/examples/fire/lib"
	"github.com/centny/flame_network/lib/src/network"
)

func main() {
	network.Network.IsServer = true
	network.Network.Transport = network.NewNetworkTransportGRPC()
	err := network.Network.Start()
	if err != nil {
		panic(err)
	}
	lib.Run()
}
