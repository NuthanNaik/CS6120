#include<bits/stdc++.h>
using namespace std;
int main(){
double Pt=50.00;
double d=1000.00;
double Pi=2*asin(1);
double lamda=(double)(3/(double)9);
vector<double>v;
for(double Ht=10;Ht<=50;Ht+=10){
    for(double Hr=1;Hr<=5;Hr++){
    double Pr;
    double Gain;
    Gain=10*log10((0.6*(pow(((Pi)*3)/lamda,2))));
    Pr=(double)(Pt)*(pow(Ht*Hr,2)*Gain)/pow(d,4);
    Pr=30+10*log10(Pr);
    v.push_back(Pr);
    }
}
int freq2=100;
int k=0;
for(double Ht=10;Ht<=50;Ht+=10){
    for(double Hr=1;Hr<=5;Hr++){
        cout<<Ht<<" "<<Hr<<" "<<v[k]<<endl;
        k++;
    }
}
}
