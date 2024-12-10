#include "version.h"

#include <cstdlib>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using std::atoi;
using std::length_error;
using std::string;
using std::stringstream;
using std::vector;

const uint8_t EMPTY_VALUE= 0;
const char SEPARATOR= '.';

Version::Version() : Version(EMPTY_VALUE, EMPTY_VALUE, EMPTY_VALUE) {
}

Version::Version(const string& version) {
    assign(version);
}

Version::Version(uint8_t major, uint8_t minor, uint8_t step) {
    uint8_t state[3] = { step, minor, major }, *ptr = state;
    deserialize(&ptr);
}

void Version::deserialize(uint8_t** state_stream) {
    step = **state_stream;
    minor = *(++(*state_stream));
    major = *(++(*state_stream));
    ++(*state_stream);

    stringstream buffer;
    buffer << (int) major << SEPARATOR << (int) minor << SEPARATOR << (int) step;
    sem_ver = buffer.str();
}

void Version::serialize(vector<uint8_t>& state) const {
    state.push_back(step);
    state.push_back(minor);
    state.push_back(major);
}

bool Version::empty() const {
    return major == EMPTY_VALUE && minor == EMPTY_VALUE && step == EMPTY_VALUE;
}

void Version::assign(const std::string& new_version) {
    sem_ver.assign(new_version);
    string tempStr;
    vector<string> parts;
    size_t i= 0;

    while(i < new_version.size()) {
        if (new_version[i] == SEPARATOR && !tempStr.empty()) {
            parts.push_back(tempStr);
            tempStr.clear();
        } else {
            tempStr+= new_version[i];
        }
        i++;
    }
    if (!tempStr.empty()) {
        parts.push_back(tempStr);
    }

    if (parts.size() != 3) {
        throw length_error("version string \'" + new_version + "\' did not split into 3 elements");
    }
    major = atoi(parts.at(0).c_str());
    minor = atoi(parts.at(1).c_str());
    step = atoi(parts.at(2).c_str());
}

Version& Version::operator =(const Version& original) {
    if (this != &original) {
        major= original.major;
        minor= original.minor;
        step= original.step;
        sem_ver = original.sem_ver;
    }
    return *this;
}

bool operator <(const Version& left, const Version& right) {
    auto compare = [](uint8_t l, uint8_t r) -> int8_t {
        if (l < r) return -1;
        if (l > r) return 1;
        return 0;
    };

    return compare(left.major, right.major) * 4 + compare(left.minor, right.minor) * 2 + compare(left.step, right.step) < 0;
}

bool operator ==(const Version& left, const Version& right) {
    return left.major == right.major && left.minor == right.minor && left.step == right.step;
}
