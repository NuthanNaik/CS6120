function f = hPlotBuildingWireframe(TRI)
%hPlotBuildingWireframe Plot building
%   hPlotBuildingWireframe(TRI) plots the building wireframe described by
%   the triangulation object TRI.

%   Copyright 2021 The MathWorks, In

f = figure("Position", [360 360 600 600]);
view(60, 30);
axis equal;
grid off;
xlabel('x'); ylabel('y'); zlabel('z');

% Plot edges
fe = featureEdges(TRI,pi/20);
numEdges = size(fe, 1);
pts = TRI.Points;
a = pts(fe(:,1),:); 
b = pts(fe(:,2),:); 
fePts = cat(1, reshape(a, 1, numEdges, 3), ...
           reshape(b, 1, numEdges, 3), ...
           nan(1, numEdges, 3));
fePts = reshape(fePts, [], 3);
plot3(fePts(:, 1), fePts(:, 2), fePts(:, 3), 'k', 'LineWidth', .5);

end
