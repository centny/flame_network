package lib

import (
	"fmt"
	"math"
	"sync"
	"time"

	"github.com/centny/flame_network/lib/src/network"
	"github.com/codingeasygo/util/uuid"
)

type Vec [2]float64

func (v Vec) Sub(o Vec) Vec {
	return Vec{v[0] - o[0], v[1] - o[1]}
}

func (v Vec) Add(o Vec) Vec {
	return Vec{v[0] + o[0], v[1] + o[1]}
}

func (v Vec) Mul(s float64) Vec {
	return Vec{v[0] * s, v[1] * s}
}

func (v Vec) Length() float64 {
	return math.Sqrt(v[0]*v[0] + v[1]*v[1])
}

func (v Vec) Normalized() Vec {
	s := 1.0 / v.Length()
	return Vec{v[0] * s, v[1] * s}
}

func (v Vec) Cross(o Vec) float64 {
	return v[0]*o[1] - v[1]*o[0]
}

func (v Vec) Dot(o Vec) float64 {
	return v[0]*o[0] + v[1]*o[1]
}

func (v Vec) AngleTo(o Vec) float64 {
	if v[0] == o[0] && v[1] == o[1] {
		return 0.0
	}
	s := v.Cross(o)
	c := v.Dot(o)
	return math.Atan2(s, c)
}

func (v Vec) Reflect(o Vec) Vec {
	return v.Sub(o.Mul(2.0 * o.Dot(v)))
}

func (v Vec) MarshalJSON() ([]byte, error) {
	return []byte(fmt.Sprintf("[%.02f,%0.02f]", v[0], v[1])), nil
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
	weaponColors []int
	playerAll    map[string]*Player
	bulletAll    map[string]*Bullet
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
		weaponColors:     []int{0xFFFF4B91, 0xFFFFCD4B, 0xFFD6D46D, 0xFFF4DFB6, 0xFFDE8F5F, 0xFF9A4444},
		playerAll:        map[string]*Player{},
		bulletAll:        map[string]*Bullet{},
		lock:             sync.RWMutex{},
	}
	game.initSeat()
	game.boss = NewBoss(game, uuid.New())
	game.RegisterNetworkCall("join", game.onPlayerJoin)
	game.RegisterNetworkEvent(game.Group, game)
	// network.ComponentHub.RegisterFactory("", game.Group, game.onNetworkCreate)
	return
}

func (g *FireGame) initSeat() {
	for i := 0; i < 3; i++ {
		var gap = (g.Width - 3*100) / 4
		g.seatPosition[i] = Vec{-g.Width/2 + float64(i+1)*(gap+50), g.Height / 2}
	}
	for i := 0; i < 3; i++ {
		var gap = (g.Width - 3*100) / 4
		g.seatPosition[3+i] = Vec{-g.Width/2 + float64(i+1)*(gap+50), -g.Height / 2}
	}
	g.seatPosition[6] = Vec{-g.Width / 2, 0}
	g.seatPosition[7] = Vec{-g.Width / 2, 0}
}

func (g *FireGame) requestSeat() int {
	for i := 0; i < 8; i++ {
		if !g.seatUsed[i] {
			g.seatUsed[i] = true
			return i
		}
	}
	return -1
}

func (g *FireGame) releaseSeat(seat int) {
	g.seatUsed[seat] = false
}

func (g *FireGame) onPlayerJoin(ctx *network.NetworkSession, _ string, name string) (result string, err error) {
	owner := ctx.User()
	if len(owner) < 1 || len(name) < 1 {
		err = fmt.Errorf("user/name is required")
		return
	}
	g.lock.Lock()
	defer g.lock.Unlock()

	if g.playerAll[owner] != nil {
		result = "OK"
		return
	}
	seat := g.requestSeat()
	if seat < 0 {
		result = "Seat Full"
		return
	}
	player := NewPlayer(g, uuid.New())
	player.Position = g.seatPosition[seat]
	player.SetName(name)
	player.Owner = owner
	player.SetSeat(seat)
	g.playerAll[owner] = player
	network.Infof("Game(%v) player %v/%v join game on %v", player.Group, owner, name, g.Group)
	result = "OK"
	return
}

// func (g *FireGame) onNetworkCreate(key, group, id string) (c *network.NetworkComponent, err error) {
// 	network.Infof("Game(%v) network create %v by %v", g.Group, key, id)
// 	err = fmt.Errorf("onNetworkCreate %v.%v is not supported", group, key)
// 	return
// }

func (g *FireGame) OnNetworkState(all network.NetworkConnectionSet, conn network.NetworkConnection, state network.NetworkState, info interface{}) {
	network.Infof("Game(%v) 1/%v connect state to %v", g.Group, len(all), state)
	if g.IsServer() && len(all) < 1 && (state == network.NetworkStateClosed || state == network.NetworkStateError) {
		g.lock.Lock()
		defer g.lock.Unlock()
		owner := conn.Session().User()
		player := g.playerAll[owner]
		if player != nil {
			delete(g.playerAll, owner)
			seat := player.IntDef(0, "seat")
			name := player.StrDef("", "name")
			g.releaseSeat(seat)
			network.Infof("Game(%v) player %v/%v leave game on %v", g.Group, owner, name, g.Group)
		}
	}
}

func (g *FireGame) OnNetworkPing(conn network.NetworkConnection, ping time.Duration) {

}

func (g *FireGame) RemoveObject(v interface{}) {

}

func (g *FireGame) AddBulllet(bullet *Bullet) {
	g.lock.Lock()
	defer g.lock.Unlock()
	g.bulletAll[bullet.CID] = bullet
}

func (g *FireGame) Update(delta float64) {
	g.lock.RLock()
	defer g.lock.RUnlock()
	if !g.boss.Removed {
		g.boss.Update(delta)
	}
	for _, player := range g.playerAll {
		if !player.Removed {
			player.Update(delta)
		}
	}
	for _, bullet := range g.bulletAll {
		if !bullet.Removed {
			bullet.Update(delta)
		}
	}
}

type Boss struct {
	*network.NetworkComponent
	Game     *FireGame
	Position Vec
	Radius   float64
	Healthy  int
}

func NewBoss(game *FireGame, cid string) (boss *Boss) {
	boss = &Boss{
		NetworkComponent: network.NewNetworkComponent(FactoryTypeBoss, game.Group, cid),
		Game:             game,
		Position:         Vec{0, 0},
		Radius:           160,
	}
	boss.SetHealthy(100)
	boss.RegisterNetworkProp()
	boss.NetworkComponent.OnNetworkRemove = boss.Remove
	return
}

func (b *Boss) SetHealthy(v int) {
	b.Healthy = v
	b.SetValue("healthy", v)
}

func (b *Boss) Update(delta float64) {
}

func (b *Boss) Hurt(playerID string, power int) {
	b.Healthy -= power
	b.SetHealthy(b.Healthy)
	if b.Healthy <= 0 {
		b.Remove()
		player := network.ComponentHub.FindComponent(playerID)
		if player != nil {
			player.Refer.(*Player).SendReward(10000)
		}
	}
}

func (b *Boss) Remove() {
	b.Removed = true
}

func (b *Boss) OnRemove() {
	b.Game.RemoveObject(b)
}

type Bullet struct {
	*network.NetworkComponent
	Game      *FireGame
	PlayerID  string
	Position  Vec
	Radius    float64
	Direct    Vec
	Speed     float64
	Power     int
	startTime time.Time
}

func NewBullet(game *FireGame, playerID string, cid string, power int) (bullet *Bullet) {
	bullet = &Bullet{
		NetworkComponent: network.NewNetworkComponent(FactoryTypeBullet, game.Group, cid),
		Game:             game,
		PlayerID:         playerID,
		Position:         Vec{0, 0},
		Radius:           16,
		Direct:           Vec{0, 1},
		Power:            power,
		startTime:        time.Now(),
	}
	bullet.SetDirect(Vec{0, 1})
	bullet.SetSpeed(1000)
	bullet.SetColor(0xffffffff)
	bullet.SetPosition(Vec{0, 0})
	bullet.RegisterNetworkProp()
	bullet.NetworkComponent.OnNetworkRemove = bullet.OnRemove
	return
}

func (b *Bullet) SetDirect(v Vec) {
	b.Direct = v
	b.SetValue("direct", v)
}

func (b *Bullet) SetSpeed(v float64) {
	b.Speed = v
	b.SetValue("speed", v)
}

func (b *Bullet) SetColor(v int) {
	b.SetValue("color", v)
}

func (b *Bullet) SetPosition(v Vec) {
	b.Position = v
	b.SetValue("position", v)
}

func (b *Bullet) Update(delta float64) {
	if b.IsServer() {
		b.collision(delta)
		b.move(delta)
		if time.Since(b.startTime) > 5*time.Second {
			b.Remove()
		}
	}
}

func (b *Bullet) collision(delta float64) {
	var p = b.Position.Add(b.Direct.Mul(b.Speed * delta))

	//wall
	if p[0] > b.Game.Width/2 { //right
		b.Direct = b.Direct.Reflect(Vec{-1, 0})
	}
	if p[0] < -b.Game.Width/2 { //left
		b.Direct = b.Direct.Reflect(Vec{1, 0})
	}
	if p[1] > -b.Game.Height/2 { //top
		b.Direct = b.Direct.Reflect(Vec{0, 1})
	}
	if p[1] < b.Game.Height/2 { //bottom
		b.Direct = b.Direct.Reflect(Vec{0, -1})
	}

	//boss
	if !b.Game.boss.Removed && p.Sub(b.Game.boss.Position).Length() <= b.Game.boss.Radius {
		b.Game.boss.Hurt(b.PlayerID, b.Power)
		b.Remove()
	}
}

func (b *Bullet) move(delta float64) {
	b.SetPosition(b.Position.Add(b.Direct.Mul(b.Speed * delta)))
}

func (b *Bullet) Remove() {
	b.Removed = true
}

func (b *Bullet) OnRemove() {
	b.Game.RemoveObject(b)
}

type Player struct {
	*network.NetworkComponent
	Game         *FireGame
	Position     Vec
	WeaponUsing  int
	WeaponDirect Vec
}

func NewPlayer(game *FireGame, cid string) (player *Player) {
	player = &Player{
		NetworkComponent: network.NewNetworkComponent(FactoryTypePlayer, game.Group, cid),
		Game:             game,
	}
	player.Refer = player
	player.SetName("")
	player.SetSeat(0)
	player.SetWeaponUsing(0)
	player.SetWeaponAngle(0)
	player.SetWeaponDirect(Vec{0, 1})
	player.RegisterNetworkProp()
	player.RegisterNetworkTrigger("reward", player.OnReward)
	player.RegisterNetworkCall("switch", player.OnSwitchWeapon)
	player.RegisterNetworkCall("turn", player.OnTurnTo)
	player.RegisterNetworkCall("fire", player.OnFireTo)
	player.NetworkComponent.OnNetworkRemove = player.OnRemove
	return
}

func (p *Player) SetName(v string) {
	p.SetValue("name", v)
}

func (p *Player) SetSeat(v int) {
	p.SetValue("seat", v)
}

func (p *Player) SetWeaponUsing(v int) {
	p.WeaponUsing = v
	p.SetValue("weapon.using", v)
}

func (p *Player) SetWeaponAngle(v float64) {
	p.SetValue("weapon.angle", v)
}

func (p *Player) SetWeaponDirect(v Vec) {
	p.WeaponDirect = v
	p.SetValue("weapon.direct", v)
}

func (p *Player) Update(delta float64) {

}

func (p *Player) turnTo(arg Vec) {
	var direct = arg.Sub(p.Position).Normalized()
	var r = direct.AngleTo(Vec{0, 1})
	var angle = math.Pi - r
	p.SetWeaponAngle(angle)
	p.SetWeaponDirect(direct)
}

func (p *Player) createBullet() *Bullet {
	var b = NewBullet(p.Game, p.CID, uuid.New(), p.WeaponUsing+1)
	var pos = p.Position.Add(p.WeaponDirect.Mul(50))
	b.SetPosition(pos)
	b.SetDirect(p.WeaponDirect)
	b.SetColor(p.Game.weaponColors[p.WeaponUsing])
	return b
}

func (p *Player) fireTo(arg Vec) {
	p.turnTo(arg)
	p.Game.AddBulllet(p.createBullet())
}

func (p *Player) SendReward(v float64) {
	p.NetworkTrigger("reward", v)
}

func (p *Player) Remove() {
	p.Removed = true
}

func (p *Player) OnReward(v float64) {
	network.Infof("Game(%v) reward %v", p.Group, v)
}

func (p *Player) OnSwitchWeapon(ctx *network.NetworkSession, uuid string) (err error) {
	p.SetWeaponUsing((p.WeaponUsing + 1) % len(p.Game.weaponColors))
	return
}

func (p *Player) OnTurnTo(ctx *network.NetworkSession, uuid string, arg Vec) (err error) {
	p.turnTo(arg)
	return
}

func (p *Player) OnFireTo(ctx *network.NetworkSession, uuid string, arg Vec) (err error) {
	p.fireTo(arg)
	return
}

func (p *Player) OnRemove() {
	p.Game.RemoveObject(p)
}
