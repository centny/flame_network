package component

import (
	"fmt"

	"github.com/centny/flame_network/lib/src/network"
)

type NetworkSequencedValue struct {
	Component *network.NetworkComponent
	Name      string
	sequence  int64
	value     interface{}
}

func NewNetworkSequencedValue(component *network.NetworkComponent, name string, defaultValue interface{}) (value *NetworkSequencedValue) {
	value = &NetworkSequencedValue{Component: component, Name: name}
	value.Set(defaultValue)
	return
}

func (n *NetworkSequencedValue) Sequence() int64 {
	return n.sequence
}

func (n *NetworkSequencedValue) Get() interface{} {
	return n.value
}

func (n *NetworkSequencedValue) Set(v interface{}) {
	n.sequence++
	n.value = v
	n.Component.SetValue(n.Name, n)
}

func (n *NetworkSequencedValue) MarshalJSON() (data []byte, err error) {
	data = []byte(fmt.Sprintf("[%d,%v]", n.sequence, network.JsonEncode(n.value)))
	return
}

func (n *NetworkSequencedValue) UnmarshalJSON(data []byte) (err error) {
	err = fmt.Errorf("NetworkSequencedValue UnmarshalJSON not supported(only work for server mode)")
	return
}

func (n *NetworkSequencedValue) Access(s network.NetworkSession) (accessed bool) {
	accessed = true
	if a, ok := n.value.(network.NetworkValue); ok {
		accessed = a.Access(s)
	}
	return
}

func (n *NetworkSequencedValue) String() string {
	return fmt.Sprintf("%v.%v:%v", n.Component.CID, n.Name, n.value)
}
