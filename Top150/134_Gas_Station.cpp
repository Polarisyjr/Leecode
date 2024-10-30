class Solution {
public:
    int canCompleteCircuit(vector<int>& gas, vector<int>& cost) {
        int ret=-1;
        std::vector<int> remain(gas.size());
        for(int i=0; i<gas.size(); i++){
            remain[i]=gas[i]-cost[i];
        }
        for(int j=1; j<gas.size(); j++){
            remain[j]+=remain[j-1];
        }
        int min=remain[0], min_index=0;
        for(int k=1; k<gas.size(); k++){
            if(remain[k]<min){
                min=remain[k];
                min_index=k;
            }
        }
        if(remain[gas.size()-1]>=0){
            ret=(min_index+1)%gas.size();
        }
        return ret;
    }
};