from TestSim import TestSim
#test change
def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();


    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.TRANSPORT_CHANNEL);

    s.runTime(300);
    s.setAppServer();
    s.runTime(60);

    s.setAppClient(3, 3);
    s.runTime(1);
    s.runTime(1000);
    s.setAppClient(5, 5);
    s.runTime(1);
    s.runTime(1000);

if __name__ == '__main__':
    main()
