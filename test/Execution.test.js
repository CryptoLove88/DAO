const Execution = artifacts.require('Execution');
const Voting = artifacts.require('Voting');
const MockERC20 = artifacts.require('libs/MockERC20');

contract('Execution', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {

        this.daotoken = await MockERC20.new('DAOToken', 'DAOT', '10000', { from: minter });
        this.daoactiontoken = await MockERC20.new('DAOActionToken', 'DAOAT', '1000', { from: minter });

        this.dao = await Dao.new("My DAO", 60, 50, 1, this.daotoken.address, { from: minter });
        this.vault = await Vault.new({ from: minter });
        this.execution = await Execution.new({ from: minter });
        this.voting = await Voting.new(this.dao.address, { from: minter });   

        await this.daoactiontoken.approve(this.vault.address, '100000000', { from: minter});

    });

    it('TestAddActionFunc', async () => {
        this.execution.addAction(1, 0, minter, alice, this.daoactiontoken.address, 100, {from : this.voting});
        this.execution.addAction(2, 0, minter, bob, this.daoactiontoken.address, 100, {from : this.voting});

        assert.equal((await this.execution.currentActionId), 2);
    });

    it('TestTriggerFunc', async () => {
        this.execution.addAction(1, 0, minter, alice, this.daoactiontoken.address, 100, {from : this.voting});

        this.execution.trigger(1, {from : this.voting});

        assert.equal((await this.daoactiontoken.balanceOf({from: alice})), 100);
        assert.equal((await this.daoactiontoken.balanceOf(this.vault)), 0);
    });    

});