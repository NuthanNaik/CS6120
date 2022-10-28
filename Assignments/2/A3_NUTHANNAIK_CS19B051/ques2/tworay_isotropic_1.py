import math

def function():
	pt = 50.00
	d = 1000.00
	v = []
	for i in range(1, 6):
		j = i*10
		for hr in range(1, 6):
			pr = (pt *((j*hr)**2))/(d**4)
			pr = 30 + 10*(math.log10(pr))
			v.append(pr)
	freq2 = 100
	k = 0
	for i in range(1, 6):
		j = i*10
		for hr in range(1, 6):
			print(str(j) + " " + str(hr) + " " + str(v[k]))
			k += 1
	print()

if __name__ == '__main__':
	function()