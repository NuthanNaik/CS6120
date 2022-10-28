import math

pi = 2*math.asin(1)

def function():
	pt = 50.00
	d = 1000.00
	lamba = 3.00/9.00
	v = []
	for hr in range(10, 60, 10):
		for ht in range(1, 6, 1):
			gain = 10* math.log10(0.6*(((pi*3)/lamba)**2))
			pr = ((pt *((hr*ht)**2))*gain)/(d**4)
			pr = 30 + 10*(math.log10(pr))
			v.append(pr)
	k = 0
	for i in range(1, 6):
		j = i*10
		for hr in range(1, 6):
			print(str(j) + " " + str(hr) + " " + str(v[k]))
			k += 1
	print()

if __name__ == '__main__':
	function()