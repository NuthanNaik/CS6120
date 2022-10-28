function tri = hTGaxResidentialTriangulation(params)
%hTGaxResidentialTriangulation Triangulation for residential scenario.
%   TRI = hTGaxResidentialTriangulation(PARAMS) returns a triangulation
%   object representing a residential scenario given a structure containing
%   the building parameters.

%   Copyright 2021 The MathWorks, Inc.

numFloors = params.BuildingLayout(3);
numRooms = [params.BuildingLayout(1) params.BuildingLayout(2)];
roomDim = params.RoomSize(1:2);
ceilingHeight = params.RoomSize(3);

% Set centroid based on tgaxDropNodes
params.GroundFloorCentroid = [params.BuildingLayout(1)*params.RoomSize(1)/2; params.BuildingLayout(2)*params.RoomSize(2)/2; 0];
groundFloorCentroid = params.GroundFloorCentroid;

% Build floor & ceiling mesh
floorDim = roomDim .* [numRooms(1) numRooms(2)];
baseFloorPts = [floorDim/2 .* [-1 -1], 0; ...
                floorDim/2 .* [1  -1], 0; ...
                floorDim/2 .* [1   1], 0; ...
                floorDim/2 .* [-1  1], 0] + groundFloorCentroid';
baseFloorMesh = [1 2 3; 3 4 1];

floorPts = zeros((numFloors+1)*4, 3);
floorMesh = zeros((numFloors+1)*2, 3);
for i = 0:numFloors
    floorPts(i*4+(1:4),:) = baseFloorPts + [0 0 i*ceilingHeight];
    floorMesh(i*2+(1:2),:) = baseFloorMesh + (i*4);
end

% Build exterior wall mesh
extWallMesh = ...
    [1 2 4*numFloors+2; 4*numFloors+2 4*numFloors+1 1; 
     2 3 4*numFloors+3; 4*numFloors+3 4*numFloors+2 2; 
     3 4 4*numFloors+4; 4*numFloors+4 4*numFloors+3 3; 
     4 1 4*numFloors+1; 4*numFloors+1 4*numFloors+4 4]; 
                     
% Build interior wall mesh (x direction)
baseWallPts = floorPts([1 4 4*numFloors+4 4*numFloors+1], :);
baseWallMesh = [1 2 3; 3 4 1];

% Formulate the building mesh
buildingPts = floorPts;
buildingMesh = [floorMesh; extWallMesh];
for i = 1:numRooms(1)-1 % Number of interior walls (x direction)
    buildingMesh = [buildingMesh; baseWallMesh+size(buildingPts, 1)]; %#ok<*AGROW>
    buildingPts = [buildingPts; baseWallPts+[roomDim(1)*i 0 0]];
end

% Build interior wall mesh (y direction)
baseWallPts = floorPts([1 2 4*numFloors+2 4*numFloors+1], :);
baseWallMesh = [1 2 3; 3 4 1];

% Formulate the building mesh
for j = 1:numRooms(2)-1 % Number of interior walls (y direction)
    buildingMesh = [buildingMesh; baseWallMesh+size(buildingPts, 1)]; %#ok<*AGROW>
    buildingPts = [buildingPts; baseWallPts+[0 roomDim(2)*j 0]];
end

% Create a triangulation object to represent the building
tri = triangulation(buildingMesh, buildingPts);

end