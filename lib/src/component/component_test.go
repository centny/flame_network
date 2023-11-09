package component

import (
	"fmt"
	"testing"

	"github.com/centny/flame_network/lib/src/network"
)

type TestNetworkValueNotAccess int

func (t TestNetworkValueNotAccess) Access(s network.NetworkSession) bool {
	return false
}

func TestNetworkSequencedValue(t *testing.T) {
	c := network.NewNetworkComponent("test", "test", "", "123")
	val := NewNetworkSequencedValue(c, "a", 0)
	fmt.Printf("-->%v\n", val)
	val.Set(1)
	fmt.Printf("-->%v\n", val)
	if v := val.Get().(int); v != 1 {
		t.Errorf("v is %v", v)
		return
	}
	if val.Sequence() != 2 {
		t.Error("error")
		return
	}
	data, err := val.MarshalJSON()
	if err != nil {
		t.Error(err)
		return
	}
	fmt.Printf("data is %v\n", string(data))

	err = val.UnmarshalJSON([]byte(""))
	if err == nil {
		t.Error(err)
		return
	}

	val2 := NewNetworkSequencedValue(c, "b", TestNetworkValueNotAccess(0))
	if val2.Access(network.NewDefaultNetworkSessionBySafeM()) {
		t.Error("error")
		return
	}
}
