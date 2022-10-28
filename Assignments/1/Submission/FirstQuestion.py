import math

with open('deploy_data.txt') as f:
    lines = f.readlines()

buildingA = int(lines[0])
buildingB = int(lines[1])
distanceBtw = int(lines[2])
transmissionFrequency = float(lines[3])
noOfBuilding = int(lines[4])
variables = [{'D1': int(lines[i]), 'Height': int(lines[i+1])} for i in range(5, 5+noOfBuilding*2,2)]
# buildingA = 20
# buildingB = 15
# distanceBtw = 2000
# transmissionFrequency = 2400
# noOfBuilding = 4
# variables = [
#   {'D1': 300, 'Height': 18},
#   {'D1': 600, 'Height': 19},
#   {'D1': 1200, 'Height': 21},
#   {'D1': 1600, 'Height': 22},
# ]

transmissionFrequency = transmissionFrequency * 1000000
waveLength = 300000000/transmissionFrequency

LOStowerA = 0
LOStowerAs = []
nearLOStowerA = 0
nearLOStowerAs = []

for i in range(0, noOfBuilding):
  D2 = distanceBtw - variables[i]['D1']
  radius = math.sqrt((waveLength*variables[i]['D1']*D2)/(variables[i]['D1'] + D2))
  LOStowerAs.append(variables[i]['Height'] - buildingA + 0.6*radius)
  LOStowerA = max(LOStowerA, LOStowerAs[-1])
  nearLOStowerAs.append(variables[i]['Height'] - buildingA + 0.4*radius)
  nearLOStowerA = max(nearLOStowerA, nearLOStowerAs[-1])


LOStowerB = buildingA - buildingB + LOStowerA
nearLOStowerB = buildingA - buildingB + nearLOStowerA

with open('output.txt', 'w') as f:
    f.write('solution is feasible for LOS\n')
    f.write('Antenna A height for LOS = ' + format(LOStowerA, '.4f') + '\n')
    f.write('Antenna B height for LOS = ' + format(LOStowerB, '.4f') + '\n')
    f.write('GAP for each building \n')
    for i in range(0, noOfBuilding):
      f.write(format(LOStowerAs[i]- LOStowerA, '.4f')+" ")
    f.write('\n')
    f.write('solution is feasible for nearLOS\n')
    f.write('Antenna A height for NLOS = ' + format(nearLOStowerA, '.4f') + '\n')
    f.write('Antenna B height for NLOS = ' + format(nearLOStowerB, '.4f') + '\n')
    f.write('GAP for each building \n')
    for i in range(0, noOfBuilding):
      f.write(format(nearLOStowerAs[i]- nearLOStowerA, '.4f')+" ")
    attenuation = 92.5 + 20*math.log10((transmissionFrequency*distanceBtw/1000000000)/1000)
    print(attenuation)
    f.write('\n')