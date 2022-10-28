function hPlotNetworkStats(statistics, wlanNodes)
%hPlotNetworkStats Plots throughput, packet loss ratio, and latencies at
%each node

%   Copyright 2021 The MathWorks, Inc.

for idx = 1:numel(statistics)
    figure;
    
    activeNodes = find(statistics{idx}.ActiveOperationInFreq);
    bandAndChannel = wlanNodes{activeNodes(1)}.BandAndChannel;
    bandAndChannelStr = ['(Band:', char(num2str(bandAndChannel{1}(1))), ', Channel:', char(num2str(bandAndChannel{1}(2))), ')'];

    % Plot the throughput at each node
    s1 = subplot(8, 1, 1:2);
    throughput = statistics{idx}.MACThroughput;
    bar(s1, throughput);
    plotTitle = 'Throughput at Each Transmitter';
    if numel(statistics) == 1
        title(gca, plotTitle);
    else
        title(gca, [plotTitle, bandAndChannelStr]);
    end
    xlabel(gca, 'Node ID');
    ylabel(gca, 'Throughput (Mbps)');
    xticks(1:numel(throughput));
    hold on;

    % Plot the packet loss ratio at each node
    s2 = subplot(8, 1, 4:5);
    plr = statistics{idx}.PacketLossRatio;
    bar(s2, plr);
    plotTitle = 'Packet-loss at Each Transmitter';
    if numel(statistics) == 1
        title(gca, plotTitle);
    else
        title(gca, [plotTitle, bandAndChannelStr]);
    end
    xlabel(gca, 'Node ID');
    ylabel(gca, 'Packet Loss Ratio');
    xticks(1:numel(plr));
    hold on;

    % Plot the average packet latency experienced at each receiver node
    s3 = subplot(8, 1, 7:8);
    avgLatency = statistics{idx}.AppAvgPacketLatency;
    bar(s3, avgLatency);
    plotTitle = 'Average Packet Latency at Each Receiver';
    if numel(statistics) == 1
        title(gca, plotTitle);
    else
        title(gca, [plotTitle, bandAndChannelStr]);
    end
    xlabel(gca, 'Node ID');
    ylabel(gca, 'Average Packet Latency (us)');
    xticks(1:numel(avgLatency));
    hold off;
end
end
