const HexSumTreePublic = artifacts.require('HexSumTreePublic')

const CHILDREN = 16

const getGas = (r) => {
  return { total: r.receipt.gasUsed, function: r.logs.filter(l => l.event == 'GasConsumed')[0].args['gas'].toNumber() }
}

contract('Hex Sum Tree (Gas analysis)', (accounts) => {
  let tree

  beforeEach(async () => {
    tree = await HexSumTreePublic.new()
    await tree.init()
  })

  const logTreeState = async () => {
    //console.log((await tree.getState()).map(x => x.toNumber()))
    const [ depth, nextKey ] = await tree.getState()
    console.log(`Tree depth:    ${depth}`);
    console.log(`Tree next key: ${nextKey.toNumber().toLocaleString()}`);
    console.log(`Tree total sum: `, (await tree.totalSum()).toNumber().toLocaleString())
  }

  const formatDivision = (result, colSize) => {
    return Math.round(result).toLocaleString().padStart(colSize, ' ')
  }
  const logGasStats = (title, gasArray, batchSize = 1) => {
    const COL_SIZE = 7
    console.log(title)
    console.log('Size:   ', gasArray.length)
    const min = (k) => Math.min(...gasArray.map(x => x[k]))
    const max = (k) => Math.max(...gasArray.map(x => x[k]))
    const avg = (k) => Math.round(gasArray.map(x => x[k]).reduce((a,b) => a + b, 0) / gasArray.length)
    console.log()
    console.log('|         |', 'Total'.padStart(COL_SIZE, ' '), '|', 'Function'.padStart(COL_SIZE, ' '), '|')
    console.log('|---------|' + '-'.padStart(COL_SIZE + 2, '-') + '|' + '-'.padStart(COL_SIZE + 2, '-') + '|')
    console.log('| Min     |', formatDivision(min('total') / batchSize, COL_SIZE), '|', formatDivision(min('function') / batchSize, COL_SIZE), '|')
    console.log('| Max     |', formatDivision(max('total') / batchSize, COL_SIZE), '|', formatDivision(max('function') / batchSize, COL_SIZE), '|')
    console.log('| Average |', formatDivision(avg('total') / batchSize, COL_SIZE), '|', formatDivision(avg('function') / batchSize, COL_SIZE), '|')
    console.log()
  }

  const insertNodes = async (nodes, value) => {
    let insertGas = []
    for (let i = 0; i < nodes; i++) {
      const r = await tree.insertNoLog(value)
      insertGas.push(getGas(r))
    }
    return insertGas
  }

  const getCheckpointTime = async () => {
    //return Math.floor(r.receipt.blockNumber / 256)
    return (await tree.getCheckpointTime()).toNumber()
  }

  const multipleUpdatesOnMultipleNodes = async (nodes, updates, startingKey, initialValue, blocksOffset) => {
    let setBns = [[]]
    let setGas = []
    for (let i = 1; i <= updates; i++) {
      setBns.push([])
      for (let j = 0; j < nodes; j++) {
        const checkpointTime = await getCheckpointTime()
        const value = initialValue + i
        const r = await tree.set(startingKey.add(j), value)
        setGas.push(getGas(r))
        if (setBns[i][setBns[i].length - 1] != checkpointTime) {
          setBns[i].push(checkpointTime)
        }
        /*
        if (checkpointTime >= 1 && checkpointTime <= 2) {
          console.log('Reached 1!');
          await logTree(5, nodes, 1)
        }
        */
        await tree.advanceTime(blocksOffset) // blocks
      }
    }
    return { setBns, setGas }
  }

  const logTree = async (levels, nodes, time) => {
    console.log()
    console.log('current time', (await tree.getCheckpointTime()).toNumber())
    console.log()
    const rr = await tree.getPast(levels + 1, 0, time)
    //console.log(rr)
    console.log(`root level ${levels + 1} node 0 time ${time}`, (await tree.getPast.call(levels + 1, 0, time)).toNumber())
    const startingKey = (new web3.BigNumber(CHILDREN)).pow(levels)
    for (let i = 0; i < levels; i++) {
      const node = startingKey.toNumber()
      await tree.getPast(levels - i, node, time)
      console.log(`parent level ${levels - i} node ${node} time ${time}`, (await tree.getPast.call(levels - i, node, time)).toNumber());
    }
    for (let j = 0; j < nodes; j++) {
      console.log(`leaf ${startingKey.add(j).toNumber()} time ${time}`, (await tree.getPastItem(startingKey.add(j), time)).toNumber());
    }
    console.log()
  }
  const round = async(blocksOffset) => {
    const STARTING_KEY = (new web3.BigNumber(CHILDREN)).pow(5)
    const NODES = 10
    const UPDATES = 30
    const SORTITION_NUMBER = 10
    const initialBlockNumber = await tree.getBlockNumber64()
    const initialCheckpointTime = await tree.getCheckpointTime()
    console.log(`initial block number ${initialBlockNumber}, term ${initialCheckpointTime}`)
    await tree.setNextKey(STARTING_KEY)

    await logTreeState()

    const insertGas = await insertNodes(NODES, 10)
    await logTreeState()
    //await logTree(5, NODES, 0)
    //await logTree(5, NODES, 1)

    const { setBns, setGas } = await multipleUpdatesOnMultipleNodes(NODES, UPDATES, STARTING_KEY, 10, blocksOffset)

    await logTreeState()
    //await logTree(5, NODES, 0)
    //await logTree(5, NODES, 2)

    // check all past values
    let sortitionGas = []
    for (let i = 1; i < setBns.length; i++) {
      for (let j = 0; j < setBns[i].length; j++) {
        console.log(SORTITION_NUMBER, setBns[i][j]);
        const r = await tree.multiRandomSortition(SORTITION_NUMBER, setBns[i][j])
        sortitionGas.push(getGas(r))
      }
    }

    await logTreeState()
    logGasStats('Inserts', insertGas)
    logGasStats('Sets', setGas)
    logGasStats('Sortitions', sortitionGas)

    const finalBlockNumber = await tree.getBlockNumber64()
    const finalCheckpointTime = await tree.getCheckpointTime()
    console.log(`final block number ${finalBlockNumber}, term ${finalCheckpointTime}`)
  }

  //for (const blocksOffset of [1, 243]) {
  for (const blocksOffset of [243]) {
    it(`multiple random sortition on a (fake) big tree with a lot of updates, ${blocksOffset} blocks in between`, async () => {
      await round(blocksOffset)
    })
  }
})
