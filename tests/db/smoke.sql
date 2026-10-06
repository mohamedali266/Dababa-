begin;
select plan(1);
select ok(true, 'pgTAP runner is wired');
select * from finish();
rollback;
