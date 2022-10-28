import math


def function():
	pt = 50.00
	ht = 50
	hr = 2
	v = []
	for i in range(100, 1001, 200):
		pr = (pt *((ht*hr)**2))/(i**4)
		pr = 30 + 10*(math.log10(pr))
		v.append(pr)
	freq2 = 100
	for i in range(len(v)):
		print(str(freq2) + " " + str(v[i]))
		freq2 += 200
	print()

if __name__ == '__main__':
	function()