

class Utils {
  static fundAddressForGas(beneficiary, funder, web3, value) {
    return web3.eth.sendTransaction(
      {
        from: funder,
        to: beneficiary,
        value: value,
      },
    )
  }
}


module.exports = Utils;
