#include<iostream>
#include<bitset>
#include<map>
#include<iomanip>
using namespace std;
#define WEIGHT_CNT 4
#define OUT_DEC_BITS 9
map<int,int> div_lut;

void rander_weight(int cnt,int weight_msb_sum){
	if(cnt){
		for(int i=0;i<10;++i){
			rander_weight(cnt-1,weight_msb_sum+(1<<i));
		}
	}
	else{
		int div_result=(1<<(9+OUT_DEC_BITS))/weight_msb_sum;
		div_lut.insert(pair<int,int>(weight_msb_sum,div_result));
	}
}
int main(){
	rander_weight(WEIGHT_CNT,0);
	map<int,int>::iterator iter;
	for(iter=div_lut.begin();iter!=div_lut.end();iter++){
		cout<<left<<setw(5)<<iter->first<<": div2mul="<<9+OUT_DEC_BITS<<"'b"<<bitset<9+OUT_DEC_BITS>(iter->second)<<";"<<endl;
	}
	cout<<"// total size of lut is "<<div_lut.size()<<endl;
}
