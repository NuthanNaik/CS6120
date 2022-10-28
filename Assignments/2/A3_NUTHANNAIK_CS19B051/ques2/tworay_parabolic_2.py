import math

def function():
	pt = 50.00
	pi = 2*math.asin(1)
	ht = 50.00
	hr = 2
	v = []
	lamba = (3.00)/9.00
	for dist in range(100, 1001, 200):
		gain = 10* math.log10(0.6*(((pi*3)/lamba)**2))
		pr = (pt *((hr*ht)**2)*gain)/(dist**4)
		pr = 30 + 10*(math.log10(pr))
		v.append(pr)
	freq2 = 100
	for i in range(len(v)):
		print(str(freq2) + " " + str(v[i]))
		freq2 += 200
	print()

if __name__ == '__main__':
	function()