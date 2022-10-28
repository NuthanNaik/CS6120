import math

pi = 2*math.asin(1)

def function():
	pt = 50.00
	freq = 9*1e8
	v = []
	dist = 100.00
	lamba = (3*1e8)/freq
	for i in range(100, 1001, 200):
		val = 4* pi* i
		val2 = val**2
		pr = (pt *(lamba**2))/val2
		pr = 30 + 10*(math.log10(pr))
		v.append(pr)
	freq2 = 100
	for i in range(len(v)):
		print(str(freq2) + " " + str(v[i]))
		freq2 += 200
	print()

if __name__ == '__main__':
	function()