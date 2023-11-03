package component

import "testing"

func TestGameLoop(t *testing.T) {
	waiter := make(chan int, 8)
	loop := NewGameLoop(LoopUpdaterF(func(delta float64) {
		waiter <- 1
	}))
	go loop.Loop()
	<-waiter
	loop.Close()
}
