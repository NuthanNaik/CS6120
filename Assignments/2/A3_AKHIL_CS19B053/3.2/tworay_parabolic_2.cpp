#include<bits/stdc++.h>
using namespace std;
int main(){
double Pt=50.00;
double Pi=2*asin(1);
double Ht=50;
double Hr=2;
double lamda=(double)(3/(double)9);
vector<double>v;
for(double dist=100;dist<=1000;dist+=200){
    double Pr;
     double Gain;
    Gain=10*log10((0.6*(pow(((Pi)*3)/lamda,2))));
    Pr=(double)(Pt)*(pow(Ht*Hr,2)*Gain)/pow(dist,4);
    Pr=30+10*log10(Pr);
    v.push_back(Pr);
}
int freq2=100;
int k=0;
for(int i=0;i<v.size();i++){
    cout<<freq2<<" "<<v[i]<<endl;
    freq2+=200;
}
cout<<endl;
}
