package lib

import (
	"fmt"
	"runtime"
	"sync"
	"time"

	"github.com/centny/flame_network/lib/src/network"
	"github.com/codingeasygo/util/converter"
	"github.com/codingeasygo/util/uuid"
	"github.com/quartercastle/vector"
)

type Vec = vector.Vector

func Run() {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

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
			delta := float64(now-timeStart) / 1000000
			timeStart = now
			game.Update(delta)
			network.Network.Sync(game.Group)
		case <-exiter:
			ticker.Stop()
		}
	}
}

const (
	FactoryTypePlayer = "Player"
	FactoryTypeBullet = "Bullet"
	FactoryTypeBoss   = "Boss"
)

type FireGame struct {
	*network.NetworkComponent
	Width        float64
	Height       float64
	seatUsed     [8]bool
	seatPosition [8]Vec
	playerAll    map[string]*Player
	boss         *Boss
	lock         sync.RWMutex
}

// final List<bool> seatUsed = List.filled(8, false);
// final List<Vector2> seatPosition = List.filled(8, Vector2.zero());
// final List<double> seatAngle = [0, 0, 0, math.pi, math.pi, math.pi, math.pi / 2, -math.pi / 2];

func NewGame() (game *FireGame) {
	game = &FireGame{
		NetworkComponent: network.NewNetworkComponent("", "group-0", "group-0"),
		Width:            1280,
		Height:           720,
		playerAll:        map[string]*Player{},
		lock:             sync.RWMutex{},
	}
	game.initSeat()
	game.boss = NewBoss(game, "boss")
	game.RegisterNetworkCall("join", game.onPlayerJoin)
	game.RegisterNetworkEvent(game.Group, game)
	// network.ComponentHub.RegisterFactory("", game.Group, game.onNetworkCreate)
	return
}

func (f *FireGame) initSeat() {
	for i := 0; i < 3; i++ {
		var gap = (f.Width - 3*100) / 4
		f.seatPosition[i] = Vec{-f.Width/2 + float64(i+1)*(gap+50), f.Height / 2}
	}
	for i := 0; i < 3; i++ {
		var gap = (f.Width - 3*100) / 4
		f.seatPosition[3+i] = Vec{-f.Width/2 + float64(i+1)*(gap+50), -f.Height / 2}
	}
	f.seatPosition[6] = Vec{-f.Width / 2, 0}
	f.seatPosition[7] = Vec{-f.Width / 2, 0}
}

func (f *FireGame) requestSeat() int {
	for i := 0; i < 8; i++ {
		if !f.seatUsed[i] {
			f.seatUsed[i] = true
			return i
		}
	}
	return -1
}

func (f *FireGame) releaseSeat(seat int) {
	f.seatUsed[seat] = false
}

func (f *FireGame) onPlayerJoin(ctx *network.NetworkSession, _ string, name string) (result string, err error) {
	owner := ctx.User()
	if len(owner) < 1 || len(name) < 1 {
		err = fmt.Errorf("user/name is required")
		return
	}
	f.lock.Lock()
	defer f.lock.Unlock()

	if f.playerAll[owner] != nil {
		result = "OK"
		return
	}
	seat := f.requestSeat()
	if seat < 0 {
		result = "Seat Full"
		return
	}
	player := NewPlayer(f, uuid.New())
	player.SetName(name)
	player.Owner = owner
	player.SetSeat(seat)
	f.playerAll[owner] = player
	network.Infof("Game(%v) player %v/%v join game on %v", player.Group, owner, name, f.Group)
	result = "OK"
	return
}

// func (f *FireGame) onNetworkCreate(key, group, id string) (c *network.NetworkComponent, err error) {
// 	network.Infof("Game(%v) network create %v by %v", f.Group, key, id)
// 	err = fmt.Errorf("onNetworkCreate %v.%v is not supported", group, key)
// 	return
// }

func (f *FireGame) OnNetworkState(all network.NetworkConnectionSet, conn network.NetworkConnection, state network.NetworkState, info interface{}) {
	if f.IsServer && len(all) < 1 && (state == network.NetworkStateClosed || state == network.NetworkStateError) {
		f.lock.Lock()
		defer f.lock.Unlock()
		owner := conn.Session().User()
		player := f.playerAll[owner]
		if player != nil {
			delete(f.playerAll, owner)
			seat := player.IntDef(0, "seat")
			name := player.StrDef("", "name")
			f.releaseSeat(seat)
			network.Infof("Game(%v) player %v/%v leave game on %v", f.Group, owner, name, f.Group)
		}
	}
}

func (f *FireGame) OnNetworkPing(conn network.NetworkConnection, ping time.Duration) {

}

func (f *FireGame) RemoveObject(v interface{}) {

}

func (f *FireGame) Update(delta float64) {
}

type Boss struct {
	*network.NetworkComponent
	Game     *FireGame
	Position Vec
	Radius   float64
}

func NewBoss(game *FireGame, cid string) (boss *Boss) {
	boss = &Boss{
		NetworkComponent: network.NewNetworkComponent(FactoryTypeBoss, game.Group, cid),
		Position:         Vec{0, 0},
		Radius:           160,
	}
	boss.SetHealthy(0)
	boss.RegisterNetworkProp()
	boss.NetworkComponent.OnNetworkRemove = boss.OnNetworkRemove
	return
}

func (b *Boss) SetHealthy(v float64) {
	b.SetValue("healthy", v)
}

func (b *Boss) OnNetworkRemove() {
	b.Game.RemoveObject(b)
}

type Bullet struct {
	*network.NetworkComponent
	Game      *FireGame
	Position  Vec
	Radius    float64
	Direct    Vec
	Speed     float64
	startTime time.Time
}

func NewBullet(game *FireGame, cid string) (bullet *Bullet) {
	bullet = &Bullet{
		NetworkComponent: network.NewNetworkComponent(FactoryTypeBullet, game.Group, cid),
		Position:         Vec{0, 0},
		Radius:           16,
		Direct:           Vec{0, 1},
		startTime:        time.Now(),
	}
	bullet.SetDirect(Vec{0, 1})
	bullet.SetSpeed(1000)
	bullet.SetColor(0xffffffff)
	bullet.SetPosition(Vec{0, 0})
	bullet.OnPropUpdate["speed"] = func(key string, val interface{}) {
		bullet.Speed = converter.Float64(val)
	}
	bullet.OnPropUpdate["direct"] = func(key string, val interface{}) {
		vals, _ := converter.ArrayFloat64Val(val)
		if len(vals) >= 2 {
			bullet.Direct = Vec{vals[0], vals[1]}
		}
	}
	bullet.OnPropUpdate["position"] = func(key string, val interface{}) {
		vals, _ := converter.ArrayFloat64Val(val)
		if len(vals) >= 2 {
			bullet.Position = Vec{vals[0], vals[1]}
		}
	}
	bullet.RegisterNetworkProp()
	bullet.NetworkComponent.OnNetworkRemove = bullet.Remove
	return
}

func (b *Bullet) SetDirect(v Vec) {
	b.SetValue("direct", v)
}

func (b *Bullet) SetSpeed(v float64) {
	b.SetValue("speed", v)
}

func (b *Bullet) SetColor(v int) {
	b.SetValue("color", v)
}

func (b *Bullet) SetPosition(v Vec) {
	b.SetValue("position", v)
}

func (b *Bullet) Update(dt float64) {
	if b.IsServer {
		b.SetPosition(b.Position.Add(b.Direct.Scale(b.Speed * dt)))
		if time.Since(b.startTime) > 5*time.Second {
			b.Remove()
		}
	}
}

func (b *Bullet) Remove() {
	b.Removed = true
	b.Game.RemoveObject(b)
}

type Player struct {
	*network.NetworkComponent
	Game     *FireGame
	Position Vec
}

func NewPlayer(game *FireGame, cid string) (player *Player) {
	player = &Player{
		NetworkComponent: network.NewNetworkComponent(FactoryTypePlayer, game.Group, cid),
	}
	player.SetName("")
	player.SetSeat(0)
	player.SetWeaponUsing(0)
	player.SetWeaponAngle(0)
	player.SetWeaponDirect(Vec{0, 1})
	player.RegisterNetworkProp()
	player.RegisterNetworkCall("switch", player.OnSwitchWeapon)
	player.RegisterNetworkCall("turn", player.OnTurnTo)
	player.RegisterNetworkCall("fire", player.OnFireTo)
	player.NetworkComponent.OnNetworkRemove = player.OnNetworkRemove
	return
}

func (p *Player) SetName(v string) {
	p.SetValue("name", v)
}

func (p *Player) SetSeat(v int) {
	p.SetValue("seat", v)
}

func (p *Player) SetWeaponUsing(v int) {
	p.SetValue("weapon.using", v)
}

func (p *Player) SetWeaponAngle(v float64) {
	p.SetValue("weapon.angle", v)
}

func (p *Player) SetWeaponDirect(v Vec) {
	p.SetValue("weapon.direct", v)
}

func (p *Player) OnSwitchWeapon(ctx *network.NetworkSession, uuid string) (err error) {
	return
}

func (p *Player) OnTurnTo(ctx *network.NetworkSession, uuid string, arg Vec) (err error) {
	fmt.Printf("OnTurnTo-->%v\n", arg)
	return
}

func (p *Player) OnFireTo(ctx *network.NetworkSession, uuid string, arg Vec) (err error) {
	fmt.Printf("OnFireTo-->%v\n", arg)
	return
}

func (p *Player) OnNetworkRemove() {
	p.Game.RemoveObject(p)
}
