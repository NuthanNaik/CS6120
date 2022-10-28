/* -*- Mode:C++; c-file-style:"gnu"; indent-tabs-mode:nil; -*- */
/*
 * Copyright (c) 2008 Timo Bingmann
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation;
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * Author: Timo Bingmann <timo.bingmann@student.kit.edu>
 */

#include "ns3/propagation-loss-model.h"
#include "ns3/jakes-propagation-loss-model.h"
#include "ns3/constant-position-mobility-model.h"

#include "ns3/config.h"
#include "ns3/command-line.h"
#include "ns3/string.h"
#include "ns3/boolean.h"
#include "ns3/double.h"
#include "ns3/pointer.h"
#include "ns3/gnuplot.h"
#include "ns3/simulator.h"

#include <map>

using namespace ns3;

/// Round a double number to the given precision. e.g. dround(0.234, 0.1) = 0.2
/// and dround(0.257, 0.1) = 0.3
static double dround (double number, double precision)
{
  number /= precision;
  if (number >= 0)
    {
      number = floor (number + 0.5);
    }
  else
    {
      number = ceil (number - 0.5);
    }
  number *= precision;
  return number;
}

static double DbmToW(double dbm){
  double mw = std::pow (10.0,dbm/10.0);
  return mw / 1000.0;
}

static double DbmFromW(double w){
  double dbm = std::log10 (w * 1000.0) * 10.0;
  return dbm;
}


static Gnuplot
TestDeterministic (Ptr<FriisPropagationLossModel> model)
{
  Ptr<ConstantPositionMobilityModel> a = CreateObject<ConstantPositionMobilityModel> ();
  Ptr<ConstantPositionMobilityModel> b = CreateObject<ConstantPositionMobilityModel> ();

  Gnuplot plot;

  plot.AppendExtra ("set xlabel 'Distance'");
  plot.AppendExtra ("set ylabel 'rxPower (dBm)'");
  plot.AppendExtra ("set key top right");

  double txPowerDbm = DbmFromW(50); // dBm

  Gnuplot2dDataset dataset;

  dataset.SetStyle (Gnuplot2dDataset::LINES);

  {
    a->SetPosition (Vector (0.0, 0.0, 0.0));
    model->SetFrequency (900*1e6);

    for (double dist = 100.0; dist <= 1000.0; dist += 200.0)
      {
        b->SetPosition (Vector (dist, 0.0, 0.0));
        // CalcRxPower() returns dBm.
        double rxPowerDbm = model->CalcRxPower (txPowerDbm, a, b);

        dataset.Add (dist, rxPowerDbm);

        Simulator::Stop (Seconds (1.0));
        Simulator::Run ();
      }
  }

  std::ostringstream os;
  os << "txPower " << txPowerDbm << "dBm";
  dataset.SetTitle (os.str ());

  plot.AddDataset (dataset);

  plot.AddDataset ( Gnuplot2dFunction ("-94 dBm CSThreshold", "-94.0") );

  return plot;
}

static Gnuplot
TestProbabilistic (Ptr<PropagationLossModel> model, unsigned int samples = 100000)
{
  Ptr<ConstantPositionMobilityModel> a = CreateObject<ConstantPositionMobilityModel> ();
  Ptr<ConstantPositionMobilityModel> b = CreateObject<ConstantPositionMobilityModel> ();

  Gnuplot plot;

  plot.AppendExtra ("set xlabel 'Distance'");
  plot.AppendExtra ("set ylabel 'rxPower (dBm)'");
  plot.AppendExtra ("set zlabel 'Probability' offset 0,+10");
  plot.AppendExtra ("set view 50, 120, 1.0, 1.0");
  plot.AppendExtra ("set key top right");

  plot.AppendExtra ("set ticslevel 0");
  plot.AppendExtra ("set xtics offset -0.5,0");
  plot.AppendExtra ("set ytics offset 0,-0.5");
  plot.AppendExtra ("set xrange [100:]");

  double txPowerDbm = +20; // dBm

  Gnuplot3dDataset dataset;

  dataset.SetStyle ("with linespoints");
  dataset.SetExtra ("pointtype 3 pointsize 0.5");

  typedef std::map<double, unsigned int> rxPowerMapType;

  // Take given number of samples from CalcRxPower() and show probability
  // density for discrete distances.
  {
    a->SetPosition (Vector (0.0, 0.0, 0.0));

    for (double distance = 100.0; distance < 2500.0; distance += 100.0)
      {
        b->SetPosition (Vector (distance, 0.0, 0.0));

        rxPowerMapType rxPowerMap;

        for (unsigned int samp = 0; samp < samples; ++samp)
          {
            // CalcRxPower() returns dBm.
            double rxPowerDbm = model->CalcRxPower (txPowerDbm, a, b);
            rxPowerDbm = dround (rxPowerDbm, 1.0);

            rxPowerMap[ rxPowerDbm ]++;

            Simulator::Stop (Seconds (0.01));
            Simulator::Run ();
          }

        for (rxPowerMapType::const_iterator i = rxPowerMap.begin ();
             i != rxPowerMap.end (); ++i)
          {
            dataset.Add (distance, i->first, (double)i->second / (double)samples);
          }
        dataset.AddEmptyLine ();
      }
  }

  std::ostringstream os;
  os << "txPower " << txPowerDbm << "dBm";
  dataset.SetTitle (os.str ());

  plot.AddDataset (dataset);

  return plot;
}

static Gnuplot
TestDeterministicByTime (Ptr<PropagationLossModel> model,
                         Time timeStep = Seconds (0.001),
                         Time timeTotal = Seconds (1.0),
                         double distance = 100.0)
{
  Ptr<ConstantPositionMobilityModel> a = CreateObject<ConstantPositionMobilityModel> ();
  Ptr<ConstantPositionMobilityModel> b = CreateObject<ConstantPositionMobilityModel> ();

  Gnuplot plot;

  plot.AppendExtra ("set xlabel 'Time (s)'");
  plot.AppendExtra ("set ylabel 'rxPower (dBm)'");
  plot.AppendExtra ("set key center right");

  double txPowerDbm = +20; // dBm

  Gnuplot2dDataset dataset;

  dataset.SetStyle (Gnuplot2dDataset::LINES);

  {
    a->SetPosition (Vector (0.0, 0.0, 0.0));
    b->SetPosition (Vector (distance, 0.0, 0.0));

    Time start = Simulator::Now ();
    while( Simulator::Now () < start + timeTotal )
      {
        // CalcRxPower() returns dBm.
        double rxPowerDbm = model->CalcRxPower (txPowerDbm, a, b);

        Time elapsed = Simulator::Now () - start;
        dataset.Add (elapsed.GetSeconds (), rxPowerDbm);

        Simulator::Stop (timeStep);
        Simulator::Run ();
      }
  }

  std::ostringstream os;
  os << "txPower " << txPowerDbm << "dBm";
  dataset.SetTitle (os.str ());

  plot.AddDataset (dataset);

  plot.AddDataset ( Gnuplot2dFunction ("-94 dBm CSThreshold", "-94.0") );

  return plot;
}

int main (int argc, char *argv[])
{
  CommandLine cmd (__FILE__);
  cmd.Parse (argc, argv);
  
  GnuplotCollection gnuplots ("main-propagation-loss.pdf");

  {
    Ptr<FriisPropagationLossModel> friis = CreateObject<FriisPropagationLossModel> ();

    Gnuplot plot = TestDeterministic (friis);
    plot.SetTitle ("ns3::FriisPropagationLossModel (Default Parameters)");
    gnuplots.AddPlot (plot);
  }

  gnuplots.GenerateOutput (std::cout);

  // produce clean valgrind
  Simulator::Destroy ();
  return 0;
}
