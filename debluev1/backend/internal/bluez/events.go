package bluez

import (
	"log"

	"github.com/godbus/dbus/v5"
)

type Event struct {
	Type string `json:"type"`
	Path string `json:"path"`
}

func (c *Client) WatchEvents(onEvent func(Event)) error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}

	rule := "type='signal',interface='org.freedesktop.DBus.Properties'"
	call := conn.BusObject().Call("org.freedesktop.DBus.AddMatch", 0, rule)

	if call.Err != nil {
		return call.Err
	}

	signals := make(chan *dbus.Signal, 10)
	conn.Signal(signals)

	go func() {
		for signal := range signals {
			if len(signal.Body) == 0 {
				continue
			}

			log.Println("BlueZ event:", signal.Path)

			onEvent(Event{
				Type: "bluetooth_event",
				Path: string(signal.Path),
			})
		}
	}()

	return nil
}
