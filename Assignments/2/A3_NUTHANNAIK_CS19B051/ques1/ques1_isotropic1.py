import math

pi = 2*math.asin(1)

def function():
	pt = 50.00
	d = 10000.00
	v = []
	for i in range(1, 10):
		j = i*1e8
		lamba = (3*(10**8))/j
		val = 4* pi* d
		val2 = val**2
		pr = (pt *(lamba**2))/val2
		pr = 50 + 10*(math.log10(pr))
		v.append(pr)
	freq2 = 100
	for i in range(len(v)):
		print(str(freq2) + " " + str(v[i]))
		freq2 += 100
	print()

if __name__ == '__main__':
	function()