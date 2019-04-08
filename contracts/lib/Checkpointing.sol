pragma solidity ^0.4.24;


library Checkpointing {
    struct Checkpoint {
        uint64 time; // generic: it can be blockNumber, timestamp, term or any other unit
        uint192 value;
    }

    struct History {
        Checkpoint[] history;
    }

    uint256 private constant MAX_UINT192 = uint256(uint192(-1));
    uint256 private constant MAX_UINT64 = uint256(uint64(-1));
    string private constant ERROR_WRONG_MAX_LENGTH = "CHKP_WRONG_MAX_LENGTH";

    function add192(History storage self, uint64 time, uint192 value) internal {
        if (self.history.length == 0 || self.history[self.history.length - 1].time < time) {
            self.history.push(Checkpoint(time, value));
        } else {
            Checkpoint storage currentCheckpoint = self.history[self.history.length - 1];
            require(time == currentCheckpoint.time); // ensure list ordering

            currentCheckpoint.value = value;
        }
    }

    function get192(History storage self, uint64 time, uint256 maxLength) internal view returns (uint192) {
        uint256 length = self.history.length;

        if (length == 0) {
            return 0;
        }

        if (time < self.history[0].time) {
            return 0;
        }

        uint256 low;
        if (maxLength > 0 && maxLength < length) {
            low = length - maxLength;
            require(time >= self.history[low].time, ERROR_WRONG_MAX_LENGTH);
        }
        uint256 high = length - 1;

        while (high > low) {
            // short-circuit
            if (time >= self.history[high].time) {
                return self.history[high].value;
            }

            uint64 timeLow = self.history[low].time;
            uint256 d = uint256(self.history[high].time - timeLow);
            // ceiling weighted mid point
            uint256 mid = low + ((high - low) * (time - timeLow) + d - 1) / d;

            if (time == self.history[mid].time) {
                return self.history[mid].value;
            } else if (time > self.history[mid].time) {
                low = mid;
            } else { // time < self.history[mid].time
                high = mid - 1;
            }
        }

        return self.history[low].value;
    }

    function lastUpdated(History storage self) internal view returns (uint64) {
        if (self.history.length > 0) {
            return self.history[self.history.length - 1].time;
        }

        return 0;
    }

    function add(History storage self, uint64 time, uint256 value) internal {
        require(value <= MAX_UINT192);

        add192(self, time, uint192(value));
    }

    function get(History storage self, uint64 time) internal view returns (uint256) {
        return uint256(get192(self, time, 0));
    }

    function get30(History storage self, uint64 time) internal view returns (uint256) {
      // TODO!!!!!!!!!!!
      return uint256(get192(self, time, 30));
    }

    function get(History storage self, uint64 time, uint256 maxLength) internal view returns (uint256) {
        return uint256(get192(self, time, maxLength));
    }

    function getLast(History storage self) internal view returns (uint256) {
        if (self.history.length > 0) {
            return uint256(self.history[self.history.length - 1].value);
        }

        return 0;
    }
}
