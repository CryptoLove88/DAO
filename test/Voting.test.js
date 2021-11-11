const { expect } = require("chai");

const Vault = artifacts.require('Vault');
const Dao = artifacts.require('DAO');
const Execution = artifacts.require('Execution');
const Voting = artifacts.require('Voting');
const MockERC20 = artifacts.require('libs/MockERC20');

contract('Voting', ([alice, bob, carol, dev, minter]) => {
  beforeEach(async () => {

      //create tokens to use in DAO 
      this.daotoken = await MockERC20.new('DAOToken', 'DAOT', '10000', { from: minter });
      this.daoactiontoken = await MockERC20.new('DAOActionToken', 'DAOAT', '1000', { from: minter });

      this.dao = await Dao.new("My DAO", 60, 50, 1, this.daotoken.address, { from: minter });
      this.vault = await Vault.new({ from: minter });
      this.execution = await Execution.new({ from: minter });
      this.voting = await Voting.new(this.dao.address, { from: minter });

      await this.execution.setVaultAddress(this.vault.address, { from: minter });
      await this.execution.setVotingAddress(this.voting.address, { from: minter });
      await this.voting.setExecutionAddress(this.execution.address, { from: minter });
      await this.vault.setExecutionAddress(this.execution.address, { from: minter });

      console.log(this.vault.address);
      await this.daoactiontoken.approve(this.vault.address, '100000000', { from: minter});
      await this.vault.deposit(this.daoactiontoken.address, '500', { from: minter});

      await this.daotoken.transfer(alice, '3000', { from: minter});
      await this.daotoken.transfer(bob, '2000', { from: minter});
      await this.daotoken.transfer(carol, '1000', { from: minter});

  });

  // Test case
  it('E2Etest', async () => {
    //vote Id : 1
    await this.voting.forward(100, 
      [0],
      [bob],
      [this.daoactiontoken],
      [500],
      { from : minter}
    );

    //vote Id : 2
    await this.voting.forward(150, 
      [0],
      [carol],
      [this.daoactiontoken],
      [500],
      { from : minter}
    );

    //Expect currentVoteId is 2 because two votes are made
    assert.equal((await this.voting.currentVoteId), 2);
    
    //Vote 1 will be failed because support percentage is less than 50
    await this.voting.participateVote(1, false, {from : minter});

    //Vote 2 will be succeeded because support percentage is 67 as bigger than 50 
    await this.voting.participateVote(2, true, {from : minter});
    await this.voting.participateVote(2, false, {from : bob});

    //It throws exception if call execute before finish the vote
    await expectThrow(await this.voting.executeVote(1));

    await time.increase(time.duration.second(100));
    await this.voting.executeVote(1);

    //Expect bob's daoactiontoken balance is 0 and vault balance is 500 because vote1 is failed
    assert.equal((await this.vault.balanceOf(this.daoactiontoken, {from: minter})), 500);
    assert.equal((await this.daoactiontoken.balanceOf({from: bob})), 0);

    await time.increase(time.duration.second(50));
    await this.voting.executeVote(2);

    //Expect carol's daoactiontoken balance is 500 and vault balance is 0 because vote2 is succeed
    assert.equal((await this.vault.balanceOf(this.daoactiontoken, {from: minter})), 0);
    assert.equal((await this.daoactiontoken.balanceOf({from: carol})), 500);

  })

});