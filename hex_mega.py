# Generate code for EEPROM burner.

cnt = 0
data = ""
for hex in open("hex.txt"):
	hex = hex.strip()
	data += str(int(hex, 16)) + ", "
	cnt += 1

print(data)
print("\nCOUNT: {}".format(cnt))
