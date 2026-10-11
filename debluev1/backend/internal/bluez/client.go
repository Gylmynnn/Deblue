package bluez

import (
	"strings"

	"github.com/Gylmynnn/deblue/backend/internal/models"
	"github.com/godbus/dbus/v5"
)

const (
	bluezService = "org.bluez"
	adapterPath  = "/org/bluez/hci0"
)

type Client struct{}

func NewClient() *Client {
	return &Client{}
}

func (c *Client) GetAdapter() (*models.AdapterInfo, error) {
	conn, err := dbus.SystemBus()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	obj := conn.Object(bluezService, dbus.ObjectPath(adapterPath))

	call := obj.Call("org.freedesktop.DBus.Properties.GetAll", 0, "org.bluez.Adapter1")
	if call.Err != nil {
		return nil, call.Err
	}

	var props map[string]dbus.Variant
	if err := call.Store(&props); err != nil {
		return nil, err
	}

	return &models.AdapterInfo{
		Powered:     getBool(props, "Powered"),
		Discovering: getBool(props, "Discovering"),
		Address:     getString(props, "Address"),
		Name:        getString(props, "Name"),
		Alias:       getString(props, "Alias"),
	}, nil
}

func (c *Client) SetAdapterPower(powered bool) error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()

	obj := conn.Object(bluezService, dbus.ObjectPath(adapterPath))

	call := obj.Call(
		"org.freedesktop.DBus.Properties.Set",
		0,
		"org.bluez.Adapter1",
		"Powered",
		dbus.MakeVariant(powered),
	)

	return call.Err
}

func (c *Client) StartScan() error {
	return c.callAdapter("org.bluez.Adapter1.StartDiscovery")
}

// func (c *Client) StopScan() error {
// 	return c.callAdapter("org.bluez.Adapter1.StopDiscovery")
// }

func (c *Client) StopScan() error {
	err := c.callAdapter("org.bluez.Adapter1.StopDiscovery")
	if err != nil && strings.Contains(err.Error(), "No discovery started") {
		return nil
	}
	return err
}

func (c *Client) GetDevices() ([]models.Device, error) {
	conn, err := dbus.SystemBus()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	obj := conn.Object(bluezService, "/")

	call := obj.Call("org.freedesktop.DBus.ObjectManager.GetManagedObjects", 0)
	if call.Err != nil {
		return nil, call.Err
	}

	var managedObjects map[dbus.ObjectPath]map[string]map[string]dbus.Variant
	if err := call.Store(&managedObjects); err != nil {
		return nil, err
	}

	devices := make([]models.Device, 0)

	for path, interfaces := range managedObjects {
		props, ok := interfaces["org.bluez.Device1"]
		if !ok {
			continue
		}

		devices = append(devices, models.Device{
			Path:      string(path),
			Name:      getString(props, "Name"),
			Address:   getString(props, "Address"),
			Connected: getBool(props, "Connected"),
			Paired:    getBool(props, "Paired"),
			Trusted:   getBool(props, "Trusted"),
			RSSI:      getInt16(props, "RSSI"),
		})
	}

	return devices, nil
}

func (c *Client) ConnectDevice(path string) error {
	return c.callDevice(path, "org.bluez.Device1.Connect")
}

func (c *Client) DisconnectDevice(path string) error {
	return c.callDevice(path, "org.bluez.Device1.Disconnect")
}

func (c *Client) PairDevice(path string) error {
	return c.callDevice(path, "org.bluez.Device1.Pair")
}

func (c *Client) SetDeviceTrusted(path string, trusted bool) error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()

	obj := conn.Object(bluezService, dbus.ObjectPath(path))

	call := obj.Call(
		"org.freedesktop.DBus.Properties.Set",
		0,
		"org.bluez.Device1",
		"Trusted",
		dbus.MakeVariant(trusted),
	)

	return call.Err
}

func (c *Client) RemoveDevice(path string) error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()

	adapter := conn.Object(bluezService, dbus.ObjectPath(adapterPath))

	call := adapter.Call(
		"org.bluez.Adapter1.RemoveDevice",
		0,
		dbus.ObjectPath(path),
	)

	return call.Err
}

func (c *Client) callAdapter(method string) error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()

	obj := conn.Object(bluezService, dbus.ObjectPath(adapterPath))
	call := obj.Call(method, 0)

	return call.Err
}

func (c *Client) callDevice(path string, method string) error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()

	obj := conn.Object(bluezService, dbus.ObjectPath(path))
	call := obj.Call(method, 0)

	return call.Err
}

func getBool(props map[string]dbus.Variant, key string) bool {
	value, ok := props[key]
	if !ok {
		return false
	}

	result, ok := value.Value().(bool)
	if !ok {
		return false
	}

	return result
}

func getString(props map[string]dbus.Variant, key string) string {
	value, ok := props[key]
	if !ok {
		return ""
	}

	result, ok := value.Value().(string)
	if !ok {
		return ""
	}

	return result
}

func getInt16(props map[string]dbus.Variant, key string) int16 {
	value, ok := props[key]
	if !ok {
		return 0
	}

	result, ok := value.Value().(int16)
	if !ok {
		return 0
	}

	return result
}
