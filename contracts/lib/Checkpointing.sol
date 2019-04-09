pragma solidity ^0.4.24;


library Checkpointing {
    struct History {
        mapping (uint256 => uint256) history; // time (uint32 actually: terms) => value
        uint256[] checkpoints; // TODO: explain
    }

    function lastUpdated(History storage self) internal view returns (uint32) {
        (,, uint256 lastCheckpoint) = _getLastCheckpoint(self);

        return uint32(lastCheckpoint);
    }

    function add(History storage self, uint32 time, uint256 value) internal {
        _addCheckpoint(self, time);
        self.history[time] = value;
    }

    function get(History storage self, uint32 time) internal view returns (uint256) {
        uint256 lucky = self.history[time];
        if (lucky > 0) {
            return lucky;
        }
        uint256 previousCheckpoint = _getPreviousCheckpoint(self, time);
        return self.history[previousCheckpoint];
    }

    function getLast(History storage self) internal view returns (uint256) {
        (,, uint256 lastCheckpoint) = _getLastCheckpoint(self);

        return self.history[lastCheckpoint];
    }

    function _addCheckpoint(History storage self, uint32 time) internal {
        require(time > 0);

        (uint256 index, uint256 position, uint32 lastCheckpoint) = _getLastCheckpoint(self);

        if (lastCheckpoint == 0) {
            self.checkpoints.push(time);
        } else if (lastCheckpoint < time) {
            (index, position) = _getNextPosition(index, position);
            if (position == 0) {
                self.checkpoints.push(time);
            } else {
                _setCheckpoint(self, index, position, time);
            }
        } else {
            require(time == lastCheckpoint); // ensure list ordering
        }
    }

    function _getNextPosition(uint256 index, uint256 position) private pure returns (uint256, uint256) {
        if (position == 7) {
            return (index + 1, 0);
        }
        return (index, position + 1);
    }

    function _setCheckpoint(History storage self, uint256 index, uint256 position, uint32 time) private {
        uint256 offset = position << 5; // * 32
        uint256 mask = ~(0xFFFFFFFF << offset);
        uint256 shiftedTime = uint256(time) << offset;
        self.checkpoints[index] = (self.checkpoints[index] & mask) + shiftedTime;
    }

    function _getLastCheckpoint(History storage self) private view returns (uint256 index, uint256 position, uint32 lastCheckpoint) {
        uint256 length = self.checkpoints.length;
        if (length == 0) {
            return (0, 0, 0);
        }
        index = length - 1;
        uint256 tuple = self.checkpoints[index];
        (position, lastCheckpoint) = _getLastTupleCheckpoint(tuple);
    }

    function _getLastTupleCheckpoint(uint256 tuple) private /* pure */ returns (uint256, uint32) {
        for (uint256 i = 7; i > 0; i--) {
            uint32 checkpoint = _getCheckpointFromTuple(tuple, i);
            if (checkpoint > 0) {
                return (i, checkpoint);
            }
        }

        // there shouldn't be empty Checkpoint tuples
        //return (0, _getCheckpointFromTuple(tuple, 0));
        return (0, uint32(tuple));
    }

    function _getCheckpointFromTuple(uint256 tuple, uint256 position) private /* pure */ returns (uint32) {
        uint256 offset = position << 5; // * 32
        uint256 mask = 0xFFFFFFFF << offset;
        return uint32((tuple & mask) >> offset);
    }

    function _getCheckpoint(History storage self, uint256 index, uint256 position) private view returns (uint32) {
        return _getCheckpointFromTuple(self.checkpoints[index], position);
    }

    function _getPreviousCheckpoint(History storage self, uint32 time) private view returns (uint32) {
        (uint256 index, uint256 position, uint32 lastCheckpoint) = _getLastCheckpoint(self);

        if (lastCheckpoint == 0) {
            return 0;
        }

        // short-circuit
        if (time >= lastCheckpoint) {
            return lastCheckpoint;
        }

        if (time < _getCheckpointFromTuple(self.checkpoints[0], 0)) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = _roll(index, position);

        while (high > low) {
            uint256 mid = (high + low + 1) / 2; // average, ceil round
            (index, position) = _unroll(mid);

            if (time >= _getCheckpoint(self, index, position)) {
                low = mid;
            } else { // time < self.history[mid].time
                high = mid - 1;
            }
        }

        (index, position) = _unroll(low);
        return _getCheckpoint(self, index, position);
    }

    function _roll(uint256 index, uint256 position) private pure returns (uint256) {
        return index * 8 + position;
    }

    function _unroll(uint256 id) private pure returns (uint256, uint256) {
        return (id / 8, id % 8);
    }
}
