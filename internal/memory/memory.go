package memory

var store = make(map[string]string)

func Put(k, v string) { store[k] = v }
func Get(k string) string { return store[k] }
