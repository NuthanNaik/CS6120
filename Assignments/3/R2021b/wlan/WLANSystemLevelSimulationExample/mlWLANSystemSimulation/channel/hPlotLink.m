function h = hPlotLink(tx,rx)
%hPlotLink Plot link
%   hPlotLink(TX,RX) plots the link between a transmitter site and receiver
%   site.

%   Copyright 2021 The MathWorks, Inc.
  
h = plot3([tx.AntennaPosition(1) rx.AntennaPosition(1)],[tx.AntennaPosition(2) rx.AntennaPosition(2)],[tx.AntennaPosition(3) rx.AntennaPosition(3)],'-');

end
