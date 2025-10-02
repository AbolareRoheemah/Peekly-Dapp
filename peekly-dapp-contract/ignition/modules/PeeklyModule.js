const { buildModule } = require('@nomicfoundation/hardhat-ignition/modules');

module.exports = buildModule('PeeklyModule', (m) => {
    const feeRecipient = "0x21dfd1CfD1d45801f46B0F40Aed056b064045aA2";
  const peekly = m.contract('Peekly', [feeRecipient]);

  return { peekly };
});