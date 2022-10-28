#include<bits/stdc++.h>
using namespace std;
double Pi= 2*asin(1);
int main(){
double Pt=50.00;
double freq=9*1e8;
vector<double>v;
double dist=100;
double lamda=(3*1e8)/freq;
for(dist=200;dist<=2000;dist+=200){
    double Pr;
    double val=(4*(Pi)*(dist));
    double val2=pow(val,2);
    double Gain;
    Gain=10*log10((0.6*(pow(((Pi)*3)/lamda,2))));
    Pr=(double)(Pt*pow(lamda,2)*Gain)/(val2);
    Pr=30+10*log10(Pr);
    v.push_back(Pr);
}
int freq2=200;
for(int i=0;i<v.size();i++){
    cout<<freq2<<" "<<v[i]<<endl;
    freq2+=200;
}
cout<<endl;
}
