package network

import (
	"encoding/json"
	"fmt"
	"reflect"
	"strings"
	"sync"
	"time"

	"github.com/codingeasygo/util/converter"
	"github.com/codingeasygo/util/uuid"
	"github.com/codingeasygo/util/xdebug"
	"github.com/codingeasygo/util/xmap"
)

var ErrFactoryNotExist = fmt.Errorf("factory is not exist")

type NetworkSession interface {
	xmap.Valuable
	Key() string
	SetKey(key string)
	Group() string
	SetGroup(group string)
	User() string
	SetUser(user string)
	Meta() xmap.Valuable
	SetMeta(meta xmap.Valuable)
	Last() time.Time
	SetLast(last time.Time)
}

type DefaultNetworkSession struct {
	xmap.Valuable
	meta xmap.Valuable
	last time.Time
}

func NewDefaultNetworkSession(context, meta xmap.Valuable) (session *DefaultNetworkSession) {
	session = &DefaultNetworkSession{
		Valuable: context,
		meta:     meta,
		last:     time.Now(),
	}
	return
}

func NewDefaultNetworkSessionByMeta(meta xmap.Valuable) (session *DefaultNetworkSession) {
	session = NewDefaultNetworkSession(xmap.NewSafe(), meta)
	return
}

func NewDefaultNetworkSessionBySafeM() (session *DefaultNetworkSession) {
	session = NewDefaultNetworkSession(xmap.NewSafe(), xmap.NewSafe())
	return
}

func (n *DefaultNetworkSession) Key() string {
	return n.meta.StrDef("", "key")
}

func (n *DefaultNetworkSession) SetKey(key string) {
	n.meta.SetValue("key", key)
}

func (n *DefaultNetworkSession) Group() string {
	return n.StrDef("", "group")
}

func (n *DefaultNetworkSession) SetGroup(group string) {
	n.SetValue("group", group)
}

func (n *DefaultNetworkSession) User() string {
	return n.StrDef("", "user")
}

func (n *DefaultNetworkSession) SetUser(user string) {
	n.SetValue("user", user)
}

func (n *DefaultNetworkSession) Meta() xmap.Valuable {
	return n.meta
}

func (n *DefaultNetworkSession) SetMeta(meta xmap.Valuable) {
	n.meta = meta
}

func (n *DefaultNetworkSession) Last() time.Time {
	return n.last
}

func (n *DefaultNetworkSession) SetLast(last time.Time) {
	n.last = last
}

type NetworkState int

const (
	NetworkStateConnecting NetworkState = 100
	NetworkStateReady      NetworkState = 200
	NetworkStateClosing    NetworkState = 300
	NetworkStateClosed     NetworkState = 400
	NetworkStateError      NetworkState = 500
)

type NetworkConnection interface {
	ID() string
	Session() NetworkSession
	State() NetworkState
	IsServer() bool
	IsClient() bool
	NetworkSync(data *NetworkSyncData)
}

type NetworkConnectionSet map[string]NetworkConnection

type NetworkCallback interface {
	NetworkEvent
	OnNetworkCall(conn NetworkConnection, arg *NetworkCallArg) (ret *NetworkCallResult, err error)
	OnNetworkSync(conn NetworkConnection, data *NetworkSyncData)
}

type NetworkTransport interface {
	Start() (err error)
	Stop() (err error)
	IsReady() (ready bool)
	Ready() (err error)
	Pause() (err error)
	NetworkSync(data *NetworkSyncData, excluded []NetworkConnection)
	NetworkCall(arg *NetworkCallArg) (ret *NetworkCallResult, err error)
}

type NetworkEvent interface {
	OnNetworkState(all NetworkConnectionSet, conn NetworkConnection, state NetworkState, info interface{})
	OnNetworkPing(conn NetworkConnection, ping time.Duration)
	OnNetworkDataSynced(conn NetworkConnection, data *NetworkSyncData)
}

func JsonEncode(v interface{}) string {
	switch v.(type) {
	case float32, float64:
		return fmt.Sprintf("%.02f", v)
	default:
		return converter.JSON(v)
	}
}

type NetworkSyncDataComponent struct {
	Factory  string
	CID      string
	Owner    string
	Removed  bool
	Props    xmap.M
	Triggers xmap.M
}

func EncodeProp(props xmap.M, session NetworkSession) xmap.M {
	propAll := xmap.M{}
	for k, v := range props {
		switch v := v.(type) {
		case NetworkValue:
			if v.Access(session) {
				propAll[k] = JsonEncode(v)
			}
		default:
			propAll[k] = JsonEncode(v)
		}
	}
	return propAll
}

func EncodeTrigger(triggers xmap.M, session NetworkSession) xmap.M {
	propAll := xmap.M{}
	for k, vals := range triggers {
		valAll := []interface{}{}
		for _, v := range vals.([]interface{}) {
			switch v := v.(type) {
			case NetworkValue:
				if v.Access(session) {
					valAll = append(valAll, JsonEncode(v))
				}
			default:
				valAll = append(valAll, JsonEncode(v))
			}
		}
		if len(valAll) > 0 {
			propAll[k] = valAll
		}
	}
	return propAll
}

func (n *NetworkSyncDataComponent) Encode(session NetworkSession) *NetworkSyncDataComponent {
	return &NetworkSyncDataComponent{
		Factory:  n.Factory,
		CID:      n.CID,
		Owner:    n.Owner,
		Removed:  n.Removed,
		Props:    EncodeProp(n.Props, session),
		Triggers: EncodeTrigger(n.Triggers, session),
	}
}

type NetworkSyncData struct {
	UUID       string
	Group      string
	Whole      bool // if components container all NetworkComponents, if true client should remove NetworkComponents which is not in components
	Components []*NetworkSyncDataComponent
}

func NewNetworkSyncDataBySyncSend(group string, whole bool) (data *NetworkSyncData) {
	data = &NetworkSyncData{
		UUID:       uuid.New(),
		Group:      group,
		Whole:      whole,
		Components: ComponentHub.SyncSend(group, whole),
	}
	return
}

func (n *NetworkSyncData) IsUpdated() bool {
	return len(n.Components) > 0 || n.Whole
}

func (n *NetworkSyncData) Encode(session NetworkSession) *NetworkSyncData {
	components := []*NetworkSyncDataComponent{}
	for _, c := range n.Components {
		components = append(components, c.Encode(session))
	}
	return &NetworkSyncData{
		UUID:       n.UUID,
		Group:      n.Group,
		Whole:      n.Whole,
		Components: components,
	}
}

var Network = NewNetworkManager()

type NetworkManager struct {
	NetworkSession
	Verbose   bool
	MinSync   time.Duration
	Keepalive time.Duration
	Timeout   time.Duration
	IsServer  bool
	IsClient  bool
	Transport NetworkTransport
	PingSpeed time.Duration
	lastSync  time.Time
}

func NewNetworkManager() (network *NetworkManager) {
	network = &NetworkManager{
		NetworkSession: NewDefaultNetworkSessionBySafeM(),
		MinSync:        30 * time.Millisecond,
		Keepalive:      3 * time.Second,
		Timeout:        5 * time.Second,
	}
	return
}

func (n *NetworkManager) Start() (err error) {
	err = n.Transport.Start()
	return
}

func (n *NetworkManager) Stop() (err error) {
	err = n.Transport.Stop()
	ComponentHub.Clear("")
	return
}

func (n *NetworkManager) IsReady() (ready bool) {
	ready = n.Transport.IsReady()
	return
}

func (n *NetworkManager) Ready() (err error) {
	if group := n.Group(); len(group) > 0 {
		ComponentHub.Clear(n.Group())
	}
	err = n.Transport.Ready()
	return
}

func (n *NetworkManager) Pause() (err error) {
	err = n.Transport.Pause()
	return
}

func (n *NetworkManager) Sync(group string, whole NetworkConnection) bool {
	if whole == nil && time.Since(n.lastSync) < n.MinSync {
		return false
	}
	var updated = false
	if n.IsServer {
		var updatedData = NewNetworkSyncDataBySyncSend(group, false)
		if updatedData.IsUpdated() {
			if whole == nil {
				n.NetworkSync(updatedData, []NetworkConnection{})
			} else {
				n.NetworkSync(updatedData, []NetworkConnection{whole})
			}
			updated = true
			n.lastSync = time.Now()
		}
		if whole != nil {
			wholeData := NewNetworkSyncDataBySyncSend(group, true)
			whole.NetworkSync(wholeData)
		}
	}
	return updated
}

func (n *NetworkManager) NetworkSync(data *NetworkSyncData, excluded []NetworkConnection) {
	n.Transport.NetworkSync(data, excluded)
}

func (n *NetworkManager) NetworkCall(arg *NetworkCallArg) (ret *NetworkCallResult, err error) {
	ret, err = n.Transport.NetworkCall(arg)
	return
}

func (n *NetworkManager) OnNetworkState(all NetworkConnectionSet, conn NetworkConnection, state NetworkState, info interface{}) {
	group := conn.Session().Group()
	if n.IsServer && conn.IsServer() && state == NetworkStateReady {
		n.Sync(group, conn)
	}
	EventHub.OnNetworkState(all, conn, state, info)
}

func (n *NetworkManager) OnNetworkCall(conn NetworkConnection, arg *NetworkCallArg) (ret *NetworkCallResult, err error) {
	ret, err = ComponentHub.OnNetworkCall(conn, arg)
	return
}

func (n *NetworkManager) OnNetworkSync(conn NetworkConnection, data *NetworkSyncData) {
	ComponentHub.OnNetworkSync(conn, data)
	n.OnNetworkDataSynced(conn, data)
}

func (n *NetworkManager) OnNetworkPing(conn NetworkConnection, ping time.Duration) {
	EventHub.OnNetworkPing(conn, ping)
}

func (n *NetworkManager) OnNetworkDataSynced(conn NetworkConnection, data *NetworkSyncData) {
	EventHub.OnNetworkDataSynced(conn, data)
}

type NetworkCallArg struct {
	UUID string
	CID  string
	Name string
	Arg  string
}

func (n *NetworkCallArg) String() string {
	return fmt.Sprintf("NetworkCallArg(uuid:%v,CID:%v,Name:%v,Arg:%v)", n.UUID, n.CID, n.Name, n.Arg)
}

type NetworkCallResult struct {
	UUID   string
	CID    string
	Name   string
	Result string
}

func (n *NetworkCallResult) String() string {
	return fmt.Sprintf("NetworkCallArg(uuid:%v,CID:%v,Name:%v,Arg:%v)", n.UUID, n.CID, n.Name, n.Result)
}

type NetworkValue interface {
	Access(s NetworkSession) bool
}

type NetworkComponentSet map[string]*NetworkComponent

type NetworkComponentFactory func(key, group, owner, cid string) (c *NetworkComponent, err error)

type SyncMap struct {
	OnUpdate func(key string, val interface{})
	value    xmap.M
	updated  map[string]int
	removed  map[string]int
}

func NewSyncMap() (s *SyncMap) {
	s = &SyncMap{
		value:   xmap.M{},
		updated: map[string]int{},
		removed: map[string]int{},
	}
	return
}

func (s *SyncMap) ValueVal(path ...string) (v interface{}, err error) {
	v, err = s.value.ValueVal(path...)
	return
}
func (s *SyncMap) SetValue(path string, val interface{}) (err error) {
	err = s.value.SetValue(path, val)
	if err == nil {
		s.updated[path] = 1
		if s.OnUpdate != nil {
			s.OnUpdate(path, val)
		}
	}
	return
}
func (s *SyncMap) Delete(path string) (err error) {
	err = s.value.Delete(path)
	s.removed[path] = 1
	return
}
func (s *SyncMap) Clear() (err error) {
	for k := range s.value {
		s.removed[k] = 1
	}
	err = s.value.Clear()
	return
}
func (s *SyncMap) Length() (l int) {
	l = s.value.Length()
	return
}
func (s *SyncMap) Exist(path ...string) bool {
	return s.value.Exist(path...)
}

func (s *SyncMap) Updated(whole bool) (value xmap.M) {
	value = xmap.New()
	if whole {
		for k, v := range s.value {
			value[k] = v
		}
	} else {
		for k := range s.updated {
			value[k] = s.value[k]
		}
	}
	s.updated = map[string]int{}
	return
}

func (s *SyncMap) Sync(value xmap.M) {
	for k, v := range value {
		s.value[k] = v
	}
}

type NetworkPropUpdate func(key string, val interface{})

type NetworkTrigger interface{}
type NetworkCall interface{}

type networkTriggerItem struct {
	Name    string
	Trigger NetworkTrigger
	Cache   chan interface{}
}

func (n *networkTriggerItem) Add(v interface{}) {
	select {
	case n.Cache <- v:
	default:
	}
}

func (n *networkTriggerItem) Send() []interface{} {
	vals := []interface{}{}
	callValue := reflect.ValueOf(n.Trigger)
	callType := callValue.Type()
	callIn := callType.NumIn()
	more := true
	for more {
		select {
		case v := <-n.Cache:
			if callIn == 1 {
				callValue.Call([]reflect.Value{reflect.ValueOf(v)})
			} else {
				callValue.Call([]reflect.Value{reflect.ValueOf(n.Name), reflect.ValueOf(v)})
			}
			vals = append(vals, v)
		default:
			more = false
		}
	}
	return vals
}

func (n *networkTriggerItem) Recv(vals ...interface{}) (err error) {
	if len(vals) < 1 {
		err = fmt.Errorf("vals is empty")
		return
	}
	callValue := reflect.ValueOf(n.Trigger)
	callType := callValue.Type()
	callIn := callType.NumIn()
	var inType reflect.Type
	if callIn == 1 {
		inType = callType.In(0)
	} else {
		inType = callType.In(1)
	}
	for _, val := range vals {
		value := reflect.New(inType)
		err = json.Unmarshal([]byte(val.(string)), value.Interface())
		if err != nil {
			return
		}
		value = reflect.Indirect(value)
		if callIn == 1 {
			callValue.Call([]reflect.Value{value})
		} else {
			callValue.Call([]reflect.Value{reflect.ValueOf(n.Name), value})
		}
	}
	return
}

const (
	LocCreator = "loc"
	NetCreator = "net"
)

type NetworkComponent struct {
	*xmap.SafeM
	Creator         string
	Factory         string
	Group           string
	Owner           string
	CID             string
	Removed         bool
	Resync          bool
	OnNetworkRemove func()
	OnNetworkSynced func()
	OnPropUpdate    map[string]NetworkPropUpdate
	Refer           interface{}
	propAll         *SyncMap
	triggerAll      map[string]*networkTriggerItem
	callAll         map[string]NetworkCall
}

func NewNetworkComponent(factory, group, owner, cid string) (c *NetworkComponent) {
	c = &NetworkComponent{
		Creator:      LocCreator,
		Factory:      factory,
		Group:        group,
		Owner:        owner,
		CID:          cid,
		OnPropUpdate: map[string]NetworkPropUpdate{},
		propAll:      NewSyncMap(),
		triggerAll:   map[string]*networkTriggerItem{},
		callAll:      map[string]NetworkCall{},
	}
	c.propAll.OnUpdate = c.onPropUpdate
	c.SafeM = xmap.NewSafeByBase(c.propAll)
	return
}

func (n *NetworkComponent) IsServer() bool {
	return Network.IsServer
}

func (n *NetworkComponent) IsClient() bool {
	return Network.IsClient
}

func (n *NetworkComponent) IsOwner() bool {
	return n.Owner == Network.User()
}

func (n *NetworkComponent) addSelfToHub() {
	ComponentHub.addComponent(n)
}

func (n *NetworkComponent) shouldRemoveSelfFromHub() (call func()) {
	remove := n.propAll.Length() < 1 && len(n.callAll) < 1
	call = func() {
		if remove {
			ComponentHub.removeComponent(n)
		}
	}
	return
}

//------ NetworkProp -------//

func (n *NetworkComponent) RegisterNetworkProp() {
	n.RLock()
	defer n.RUnlock()
	n.addSelfToHub()
}

func (n *NetworkComponent) UnregisterNetworkProp() {
	var call func()
	n.Lock()
	defer func() {
		n.Unlock()
		call()
	}()
	n.propAll.Clear()
	call = n.shouldRemoveSelfFromHub()
}

func (n *NetworkComponent) onPropUpdate(key string, val interface{}) {
	if call := n.OnPropUpdate[key]; call != nil {
		call(key, val)
	}
	if call := n.OnPropUpdate["*"]; call != nil {
		call(key, val)
	}
}

func (n *NetworkComponent) SendNetworkProp(whole bool) xmap.M {
	n.RLock()
	defer n.RUnlock()
	return n.propAll.Updated(whole)
}

func (n *NetworkComponent) RecvNetworkProp(updated xmap.M) {
	n.RLock()
	defer n.RUnlock()
	n.propAll.Sync(updated)
	for k, v := range updated {
		call := n.OnPropUpdate[k]
		if call != nil {
			call(k, v)
		}
	}
}

//------ NetworkTrigger -------//

func (n *NetworkComponent) RegisterNetworkTrigger(name string, trigger NetworkTrigger) (err error) {
	callValue := reflect.ValueOf(trigger)
	callType := callValue.Type()
	if callType.NumIn() < 1 || callType.NumIn() > 2 {
		err = fmt.Errorf("trigger %v must be (name, value) or (value)", callType)
		return
	}
	n.Lock()
	defer n.Unlock()
	if n.triggerAll[name] != nil {
		err = fmt.Errorf("NetworkTrigger %v is registered", name)
		return
	}

	n.triggerAll[name] = &networkTriggerItem{
		Name:    name,
		Trigger: trigger,
		Cache:   make(chan interface{}, 8),
	}
	n.addSelfToHub()
	return
}

func (n *NetworkComponent) UnregisterNetworkTrigger(name string) {
	var call func()
	n.Lock()
	defer func() {
		n.Unlock()
		call()
	}()
	delete(n.triggerAll, name)
	call = n.shouldRemoveSelfFromHub()
}

func (n *NetworkComponent) ClearNetworkTrigger() {
	var call func()
	n.Lock()
	defer func() {
		n.Unlock()
		call()
	}()
	n.triggerAll = map[string]*networkTriggerItem{}
	call = n.shouldRemoveSelfFromHub()
}

func (n *NetworkComponent) findNetworkTrigger(name string) *networkTriggerItem {
	n.RLock()
	defer n.RUnlock()
	return n.triggerAll[name]
}

func (n *NetworkComponent) NetworkTrigger(name string, v interface{}) (err error) {
	trigger := n.findNetworkTrigger(name)
	if trigger == nil {
		err = fmt.Errorf("NetworkComponent(%v) trigger %v is not exists", n.CID, name)
		return
	}
	trigger.Add(v)
	return
}

func (n *NetworkComponent) SendNetworkTrigger() xmap.M {
	n.RLock()
	defer n.RUnlock()
	triggerAll := xmap.M{}
	for _, trigger := range n.triggerAll {
		send := trigger.Send()
		if len(send) > 0 {
			triggerAll[trigger.Name] = send
		}
	}
	return triggerAll
}

func (n *NetworkComponent) RecvNetworkTrigger(updated xmap.M) {
	for name, v := range updated {
		trigger := n.findNetworkTrigger(name)
		if trigger == nil {
			Warnf("NetworkComponent(%v) trigger %v is not exists for recv", n.CID, name)
			continue
		}
		err := trigger.Recv(v.([]interface{})...)
		if err != nil {
			Warnf("NetworkComponent(%v) trigger %v recv error %v by %v", n.CID, name, err, v)
			continue
		}
	}
}

//------ NetworkEvent -------//

func (n *NetworkComponent) RegisterNetworkEvent(group string, event NetworkEvent) {
	EventHub.RegisterNetworkEvent(group, event)
}

func (n *NetworkComponent) UnregisterNetworkEvent(event NetworkEvent) {
	EventHub.UnregisterNetworkEvent(event)
}

//------ NetworkCall -------//

func (n *NetworkComponent) RegisterNetworkCall(name string, call NetworkCall) (err error) {
	n.Lock()
	defer n.Unlock()
	if n.callAll[name] != nil {
		err = fmt.Errorf("NetworkCall %v is registered", name)
		return
	}
	n.callAll[name] = call
	n.addSelfToHub()
	return
}

func (n *NetworkComponent) UnregisterNetworkCall(name string) {
	var call func()
	n.Lock()
	defer func() {
		n.Unlock()
		call()
	}()
	delete(n.callAll, name)
	call = n.shouldRemoveSelfFromHub()
}

func (n *NetworkComponent) ClearNetworkCall() {
	var call func()
	n.Lock()
	defer func() {
		n.Unlock()
		call()
	}()
	n.callAll = map[string]NetworkCall{}
	call = n.shouldRemoveSelfFromHub()
}

func (n *NetworkComponent) findNetworkCall(name string) NetworkCall {
	n.RLock()
	defer n.RUnlock()
	return n.callAll[name]
}

func (n *NetworkComponent) NetworkCall(name string, arg interface{}, ret interface{}) (err error) {
	res, err := Network.NetworkCall(&NetworkCallArg{
		UUID: uuid.New(),
		CID:  n.CID,
		Name: name,
		Arg:  converter.JSON(arg),
	})
	if err == nil && ret != nil {
		err = json.Unmarshal([]byte(res.Result), &ret)
	}
	return
}

func (n *NetworkComponent) CallNetworkCall(ctx NetworkSession, arg *NetworkCallArg) (ret *NetworkCallResult, err error) {
	defer func() {
		if perr := recover(); perr != nil {
			Errorf("NetworkComponent(%v/%v) call NetworkCall %v panic with\nArg:%v\nStack:\n%v\n%v", n.Factory, n.CID, arg.Name, converter.JSON(arg), perr, xdebug.CallStack())
			err = fmt.Errorf("%v", perr)
		}
	}()
	call := n.findNetworkCall(arg.Name)
	if call == nil {
		err = fmt.Errorf("NetworkComponent(%v) call %v is not exists", arg.CID, arg.Name)
		return
	}
	callValue := reflect.ValueOf(call)
	callType := callValue.Type()
	argAll := []reflect.Value{reflect.ValueOf(ctx), reflect.ValueOf(arg.UUID)}
	if callType.NumIn() > 2 {
		argType := callType.In(2)
		argValue := reflect.New(argType)
		err = json.Unmarshal([]byte(arg.Arg), argValue.Interface())
		if err != nil {
			err = fmt.Errorf("NetworkCall(%v.%v) parse arg error %v", arg.CID, arg.Name, err)
			return
		}
		argAll = append(argAll, reflect.Indirect(argValue))
	}
	retValue := callValue.Call(argAll)
	errValue := retValue[callType.NumOut()-1]
	if !errValue.IsNil() {
		err = errValue.Interface().(error)
	}
	ret = &NetworkCallResult{
		UUID:   arg.UUID,
		CID:    arg.CID,
		Name:   arg.Name,
		Result: "null",
	}
	if callType.NumOut() > 1 {
		ret.Result = converter.JSON(retValue[0].Interface())
	}
	return
}

var EventHub = NewNetworkEventHub()

type NetworkEventHub struct {
	eventAll map[NetworkEvent]string
	eventLck sync.RWMutex
}

func NewNetworkEventHub() (hub *NetworkEventHub) {
	hub = &NetworkEventHub{
		eventAll: map[NetworkEvent]string{},
		eventLck: sync.RWMutex{},
	}
	return
}

func (n *NetworkEventHub) OnNetworkState(all NetworkConnectionSet, conn NetworkConnection, state NetworkState, info interface{}) {
	group := conn.Session().Group()
	n.eventLck.RLock()
	defer n.eventLck.RUnlock()
	for event, g := range n.eventAll {
		if g == group || g == "*" {
			event.OnNetworkState(all, conn, state, info)
		}
	}
}

func (n *NetworkEventHub) OnNetworkPing(conn NetworkConnection, ping time.Duration) {
	var group = conn.Session().Group()
	n.eventLck.RLock()
	defer n.eventLck.RUnlock()
	for event, g := range n.eventAll {
		if g == group || g == "*" {
			event.OnNetworkPing(conn, ping)
		}
	}
}

func (n *NetworkEventHub) OnNetworkDataSynced(conn NetworkConnection, data *NetworkSyncData) {
	group := conn.Session().Group()
	n.eventLck.RLock()
	defer n.eventLck.RUnlock()
	for event, g := range n.eventAll {
		if g == group || g == "*" {
			event.OnNetworkDataSynced(conn, data)
		}
	}
}

func (n *NetworkEventHub) RegisterNetworkEvent(group string, event NetworkEvent) {
	n.eventLck.Lock()
	defer n.eventLck.Unlock()
	n.eventAll[event] = group
}

func (n *NetworkEventHub) UnregisterNetworkEvent(event NetworkEvent) {
	n.eventLck.Lock()
	defer n.eventLck.Unlock()
	delete(n.eventAll, event)
}

var ComponentHub = NewNetworkComponentHub()

type NetworkComponentHub struct {
	OnAdd          func(c *NetworkComponent)
	OnRemove       func(c *NetworkComponent)
	factoryAll     map[string]NetworkComponentFactory
	factoryLck     sync.RWMutex
	componentAll   NetworkComponentSet
	componentGroup map[string]NetworkComponentSet
	componentLck   sync.RWMutex
}

func NewNetworkComponentHub() (hub *NetworkComponentHub) {
	hub = &NetworkComponentHub{
		factoryAll:     map[string]NetworkComponentFactory{},
		factoryLck:     sync.RWMutex{},
		componentAll:   make(NetworkComponentSet),
		componentGroup: map[string]NetworkComponentSet{},
		componentLck:   sync.RWMutex{},
	}
	return
}

func (n *NetworkComponentHub) Clear(notGroup string) {
	n.factoryLck.Lock()
	for k := range n.factoryAll {
		if len(notGroup) < 1 || (strings.HasSuffix(k, "-*") && k != notGroup+"-*") {
			delete(n.factoryAll, k)
		}
	}
	n.factoryLck.Unlock()

	componentAll := []*NetworkComponent{}
	n.componentLck.Lock()
	for _, c := range n.componentAll {
		if len(notGroup) < 1 || c.Group != notGroup {
			componentAll = append(componentAll, c)
		}
	}
	n.componentLck.Unlock()
	for _, component := range componentAll {
		n.removeComponent(component)
	}
}

func (n *NetworkComponentHub) addComponent(c *NetworkComponent) {
	added := false
	n.componentLck.Lock()
	defer func() {
		n.componentLck.Unlock()
		if added && n.OnAdd != nil {
			n.OnAdd(c)
		}
	}()
	if component, ok := n.componentAll[c.CID]; ok {
		if component != c {
			panic(fmt.Sprintf("NetworkComponent by %v/%v is registered", c.CID, c))
		}
		return
	}
	{
		componentGroup := n.componentGroup[c.Group]
		if componentGroup == nil {
			componentGroup = NetworkComponentSet{}
			n.componentGroup[c.Group] = componentGroup
		}
		componentGroup[c.CID] = c
	}
	{
		componentGroup := n.componentGroup["*"]
		if componentGroup == nil {
			componentGroup = NetworkComponentSet{}
			n.componentGroup["*"] = componentGroup
		}
		componentGroup[c.CID] = c
	}

	n.componentAll[c.CID] = c
	added = true

}

func (n *NetworkComponentHub) callOnRemove(c *NetworkComponent) {
	if c.OnNetworkRemove != nil {
		c.OnNetworkRemove()
	}
	if n.OnRemove != nil {
		n.OnRemove(c)
	}
}

func (n *NetworkComponentHub) removeComponent(c *NetworkComponent) {
	removed := false
	n.componentLck.Lock()
	defer func() {
		n.componentLck.Unlock()
		if removed {
			n.callOnRemove(c)
		}
	}()
	removed = n.removeComponentNotLock(c)
}

func (n *NetworkComponentHub) removeComponentNotLock(c *NetworkComponent) (removed bool) {
	c = n.componentAll[c.CID]
	if c == nil {
		return
	}
	if componentGroup := n.componentGroup[c.Group]; componentGroup != nil {
		delete(componentGroup, c.CID)
	}
	if componentGroup := n.componentGroup["*"]; componentGroup != nil {
		delete(componentGroup, c.CID)
	}
	delete(n.componentAll, c.CID)
	removed = true
	return
}

func (n *NetworkComponentHub) RegisterFactory(key, group string, creator NetworkComponentFactory) {
	n.factoryLck.Lock()
	defer n.factoryLck.Unlock()
	if len(group) > 0 {
		if _, ok := n.factoryAll[group+"-*"]; ok {
			panic(fmt.Sprintf("NetworkComponentFactory by %v is registered", group+"-*"))
		}
		n.factoryAll[group+"-*"] = creator
	}
	if len(key) > 0 {
		if _, ok := n.factoryAll[key]; ok {
			panic(fmt.Sprintf("NetworkComponentFactory by %v is registered", key))
		}
		n.factoryAll[key] = creator
	}
}

func (n *NetworkComponentHub) UnregisterFactory(key, group string) {
	n.factoryLck.Lock()
	defer n.factoryLck.Unlock()
	if len(group) > 0 {
		delete(n.factoryAll, group+"-*")
	}
	if len(key) > 0 {
		delete(n.factoryAll, key)
	}
}

func (n *NetworkComponentHub) CreateComponent(key, group, owner, cid string) (c *NetworkComponent, err error) {
	creator := n.factoryAll[key]
	if creator == nil {
		creator = n.factoryAll[group+"-*"]
	}
	if creator == nil {
		creator = n.factoryAll["*"]
	}
	if creator == nil {
		err = fmt.Errorf("NetworkComponentFactory by %v/%v is not supported", group, key)
		return
	}
	c, err = creator(key, group, owner, cid)
	if err != nil {
		return
	}
	n.addComponent(c)
	return
}

func (n *NetworkComponentHub) FindComponent(cid string) *NetworkComponent {
	n.componentLck.RLock()
	defer n.componentLck.RUnlock()
	return n.componentAll[cid]
}

func (n *NetworkComponentHub) ListGroupComponent(group string) NetworkComponentSet {
	n.componentLck.RLock()
	defer n.componentLck.RUnlock()
	cs := NetworkComponentSet{}
	for k, v := range n.componentGroup[group] {
		cs[k] = v
	}
	return cs
}

func (n *NetworkComponentHub) listNotInComponent(cidAll map[string]int) NetworkComponentSet {
	n.componentLck.RLock()
	defer n.componentLck.RUnlock()
	cs := NetworkComponentSet{}
	for k, c := range n.componentAll {
		if cidAll[k] < 1 {
			cs[k] = c
		}
	}
	return cs
}

func (n *NetworkComponentHub) SyncSend(group string, whole bool) []*NetworkSyncDataComponent {
	components := []*NetworkSyncDataComponent{}
	for _, c := range n.ListGroupComponent(group) {
		if c.Removed {
			n.removeComponent(c)
			components = append(components, &NetworkSyncDataComponent{
				Factory: c.Factory,
				CID:     c.CID,
				Owner:   c.Owner,
				Removed: true,
			})
			continue
		}
		props := c.SendNetworkProp(whole)
		triggers := c.SendNetworkTrigger()
		if len(props) > 0 || len(triggers) > 0 {
			components = append(components, &NetworkSyncDataComponent{
				Factory:  c.Factory,
				CID:      c.CID,
				Owner:    c.Owner,
				Props:    props,
				Triggers: triggers,
			})
		}
	}
	return components
}

func (n *NetworkComponentHub) SyncRecv(group string, components []*NetworkSyncDataComponent, whole bool) (err error) {
	cidAll := map[string]int{}
	var componnetSynced []*NetworkComponent
	for _, c := range components {
		component := n.FindComponent(c.CID)
		if c.Removed {
			if component != nil {
				n.removeComponent(component)
			}
			continue
		}
		cidAll[c.CID] = 1
		if component == nil {
			component, err = n.CreateComponent(c.Factory, group, c.Owner, c.CID)
			if err != nil {
				break
			}
			component.Creator = NetCreator
		}
		component.Resync = whole
		if len(c.Props) > 0 {
			component.RecvNetworkProp(c.Props)
		}
		if len(c.Triggers) > 0 {
			component.RecvNetworkTrigger(c.Triggers)
		}
		component.Resync = false
		if component.OnNetworkSynced != nil {
			componnetSynced = append(componnetSynced, component)
		}
	}
	if whole {
		for _, c := range n.listNotInComponent(cidAll) {
			if c.Creator == NetCreator {
				n.removeComponent(c)
			}
		}
	}
	for _, c := range componnetSynced {
		c.OnNetworkSynced()
	}
	return
}

func (n *NetworkComponentHub) OnNetworkSync(conn NetworkConnection, data *NetworkSyncData) {
	n.SyncRecv(data.Group, data.Components, data.Whole)
}

func (n *NetworkComponentHub) OnNetworkCall(conn NetworkConnection, arg *NetworkCallArg) (ret *NetworkCallResult, err error) {
	c := n.FindComponent(arg.CID)
	if c == nil {
		err = fmt.Errorf("NetworkComponent(%v) is not exists", arg.CID)
		return
	}
	ret, err = c.CallNetworkCall(conn.Session(), arg)
	return
}
