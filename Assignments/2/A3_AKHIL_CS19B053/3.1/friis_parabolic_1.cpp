#include<bits/stdc++.h>
using namespace std;
double Pi= 2*asin(1);
int main(){
double Pt=50.00;
double freq=1*1e8;
double d=1000.00;
vector<double>v;
for(freq=1*1e8;freq<=9*1e8;freq+=1e8){
    double Pr;
    double lamda=(double)((3*pow(10,8))/freq);
    double val=(4*(Pi)*(d));
    double val2=pow(val,2);
    double Gain;
    Gain=10*log10((0.6*(pow(((Pi)*3)/lamda,2))));
    Pr=(double)((Pt*pow(lamda,2))*Gain)/(val2);
    Pr=30+10*log10(Pr);
    v.push_back(Pr);
}
int freq2=100;
for(int i=0;i<v.size();i++){
    cout<<freq2<<" "<<v[i]<<endl;
    freq2+=100;
}
cout<<endl;
}
