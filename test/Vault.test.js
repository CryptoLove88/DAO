const Execution = artifacts.require('Execution');
const Voting = artifacts.require('Voting');
const MockERC20 = artifacts.require('libs/MockERC20');
const Vault = artifacts.require('Vault');

contract('Vault', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {

        this.daotoken = await MockERC20.new('DAOToken', 'DAOT', '10000', { from: minter });
        this.daoactiontoken = await MockERC20.new('DAOActionToken', 'DAOAT', '1000', { from: minter });

        this.dao = await Dao.new("My DAO", 60, 50, 1, this.daotoken.address, { from: minter });
        this.vault = await Vault.new({ from: minter });
        this.execution = await Execution.new({ from: minter });
        this.voting = await Voting.new(this.dao.address, { from: minter });   

        await this.daoactiontoken.approve(this.vault.address, '100000000', { from: minter});

    });

    it('TestDeposit', async () => {
        await this.vault.deposit(this.daoactiontoken.address, '500', { from: minter});
        assert.equal((await this.daoactiontoken.balanceOf(this.vault)), 500);
        
    });

    it('TestTransfer', async () => {
        await this.vault.deposit(this.daoactiontoken.address, '500', { from: minter});
        await this.vault.transfer(this.daoactiontoken.address, alice,'500', { from: execution});

        assert.equal((await this.daoactiontoken.balanceOf({from: alice})), 500);
        assert.equal((await this.daoactiontoken.balanceOf(this.vault)), 0);
    });    

});