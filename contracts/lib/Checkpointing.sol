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

    //event LogAdd(bool n, uint64 t, uint192 v);
    function add192(History storage self, uint64 time, uint192 value) internal {
        if (self.history.length == 0 || self.history[self.history.length - 1].time < time) {
            //emit LogAdd(true, time, value);
            self.history.push(Checkpoint(time, value));
        } else {
            //emit LogAdd(false, time, value);
            Checkpoint storage currentCheckpoint = self.history[self.history.length - 1];
            require(time == currentCheckpoint.time); // ensure list ordering

            currentCheckpoint.value = value;
        }
    }

    event LogGet(uint64 t, uint l);
    function get192(History storage self, uint64 time) internal view returns (uint192) {
        uint256 length = self.history.length;
        LogGet(time, length);

        if (length == 0) {
            return 0;
        }

        uint256 lastIndex = length - 1;

        // short-circuit
        if (time >= self.history[lastIndex].time) {
            return self.history[lastIndex].value;
        }

        if (time < self.history[0].time) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = lastIndex;

        emit LogSearchStart(time, self.history[low].time, self.history[1].time, self.history[high].time);
        while (high > low) {
            uint256 mid = (high + low + 1) / 2; // average, ceil round
            /*
            uint256 d = uint256(self.history[high].time - self.history[low].time);
            uint256 mid = low + (high - low) * time / d;
            emit LogSearch(low, high, time, d, mid);
            emit LogSearch2(self.history[low].time, self.history[mid].time, self.history[high].time);
            */

            if (time >= self.history[mid].time) {
                low = mid;
            } else { // time < self.history[mid].time
                high = mid - 1;
            }
        }

        emit LogSearchResult(self.history[low].value);
        return self.history[low].value;
    }
    event LogSearchStart(uint64 t, uint64 tl, uint64 t1, uint64 th);
    event LogSearch(uint l, uint h, uint64 t, uint d, uint m);
    event LogSearch2(uint64 lt, uint64 mt, uint64 ht);
    event LogSearchResult(uint192 v);

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
        return uint256(get192(self, time));
    }

    function getLast(History storage self) internal view returns (uint256) {
        if (self.history.length > 0) {
            return uint256(self.history[self.history.length - 1].value);
        }

        return 0;
    }
}
