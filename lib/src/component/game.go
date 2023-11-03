package component

import (
	"time"
)

type LoopUpdater interface {
	Update(delta float64)
}

type LoopUpdaterF func(delta float64)

func (f LoopUpdaterF) Update(delta float64) {
	f(delta)
}

type GameLoop struct {
	FPS     int
	Updater LoopUpdater
	exiter  chan int
}

func NewGameLoop(updater LoopUpdater) (loop *GameLoop) {
	loop = &GameLoop{
		FPS:     30,
		Updater: updater,
		exiter:  make(chan int, 8),
	}
	return
}

func (p *GameLoop) Loop() (err error) {
	interval := time.Second / time.Duration(p.FPS)
	timeStart := time.Now().UnixNano()
	ticker := time.NewTicker(interval)
	for {
		select {
		case <-ticker.C:
			now := time.Now().UnixNano()
			// DT in ms
			delta := float64(now-timeStart) / 1000000000
			timeStart = now
			p.Updater.Update(delta)
		case <-p.exiter:
			ticker.Stop()
		}
	}
}

func (p *GameLoop) Close() (err error) {
	p.exiter <- 1
	return
}
