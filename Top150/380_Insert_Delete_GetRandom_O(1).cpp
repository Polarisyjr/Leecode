class RandomizedSet {
    vector<int> vec;
    unordered_map<int,int> hash; // val, index in vec
public:
    RandomizedSet() {
        
    }
    
    bool insert(int val) {
        if(hash.find(val)!=hash.end())
            return false;

        vec.push_back(val);
        hash[val] = vec.size()-1;
        return true;
    }
    
    bool remove(int val) {
        if(hash.find(val)==hash.end())
            return false;

        auto it = hash.find(val);
        vec[it->second] = vec.back();
        vec.pop_back();
        hash[vec[it->second]] = it->second;
        hash.erase(val);
        return true;
    }
    
    int getRandom() {
        return vec[rand()%vec.size()];
    }
};

/**
 * Your RandomizedSet object will be instantiated and called as such:
 * RandomizedSet* obj = new RandomizedSet();
 * bool param_1 = obj->insert(val);
 * bool param_2 = obj->remove(val);
 * int param_3 = obj->getRandom();
 */