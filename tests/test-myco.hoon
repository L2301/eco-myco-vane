::  test-myco: test harness for %myco vane
::
::  Tests layer lifecycle, transaction routing, RPC,
::  and cross-layer operations.
::
/+  *test
::
|%
::
::  Inline type definitions (matching myco.hoon)
::
+$  info
  $:  frozen=?
      life=@ud
      pass=@ux
      frozen-data=(unit frozen-data)
  ==
+$  frozen-data
  $:  amount=@ud
      layer=@p
      freeze-block=@ud
      last-update=@ud
  ==
+$  contract  [code=* state=* owner=@p]
+$  layer-location
  $%  [%l1 ~]
      [%l2 galaxy=@p]
      [%l3 star=@p]
  ==
+$  frozen-state
  $:  balances=(map @p @ud)
      nonces=(map @p @ud)
      lives=(map @p @ud)
      passes=(map @p @ux)
  ==
+$  melt-type
  $%  [%withdrawal who=@p]
      [%state-update accounts=(list @p)]
      [%full-state ~]
  ==
+$  execution-result  [success=? gas-used=@ud new-state=link-state]
+$  link-state
  $:  balances=(map @p @ud)
      contracts=(map @p contract)
      nonces=(map @p @ud)
      roll-call=(map @p info)
      current-height=@ud
      pending-unfreezes=(map @p @ud)
  ==
+$  link-transaction
  $%  $:  %transfer
          from=@p
          to=@p
          amount=@ud
          nonce=@ud
          signature=@ux
      ==
      $:  %deploy
          from=@p
          code=*
          initial-state=*
          nonce=@ud
          signature=@ux
      ==
      $:  %call
          from=@p
          contract=@p
          method=@t
          args=*
          nonce=@ud
          signature=@ux
      ==
      $:  %freeze
          from=@p
          nonce=@ud
          target-layer=@p
          signature=@ux
      ==
      $:  %thaw
          from=@p
          nonce=@ud
          signature=@ux
      ==
      $:  %melt
          from=@p
          zkp=*
          nonce=@ud
          block-height=@ud
          type=melt-type
      ==
      $:  %spawn
          who=@p
          frozen-state=frozen-state
      ==
      [%dissolve layer=layer-location]
      $:  %create-layer
          controller=@p
          layer=layer-location
      ==
  ==
+$  consensus-proof
  $%  [%nakamoto nonce=@ud difficulty=@ud]
  ==
+$  block
  $:  hash=@uvH
      parent-hash=@uvH
      height=@ud
      timestamp=@da
      transactions=(list link-transaction)
      consensus-data=consensus-proof
      state-root=@uvH
      creator=@p
  ==
+$  chain-state
  $:  blocks=(map @uvH block)
      block-height=(map @ud @uvH)
      best-tip=@uvH
      difficulty=@ud
  ==
+$  layer-info
  $:  location=layer-location
      controller=@p
      link-state=link-state
      chain-state=chain-state
      mempool=(list link-transaction)
      active=?
  ==
+$  layer-message
  $:  from-layer=layer-location
      to-layer=layer-location
      payload=*
  ==
+$  myco-state
  $:  l1=layer-info
      l2s=(map @p layer-info)
      l3s=(map @p layer-info)
      message-queue=(list layer-message)
      rpc-nonce=@ud
  ==
::
::  Test helpers
::
++  empty-link-state
  ^-  link-state
  :*  balances=*(map @p @ud)
      contracts=*(map @p contract)
      nonces=*(map @p @ud)
      roll-call=*(map @p info)
      current-height=0
      pending-unfreezes=*(map @p @ud)
  ==
::
++  test-genesis-block
  |=  [now=@da miner=@p]
  ^-  block
  :*  hash=`@uvH`(sham [0 now miner])
      parent-hash=*@uvH
      height=0
      timestamp=now
      transactions=~
      consensus-data=[%nakamoto nonce=0 difficulty=4]
      state-root=`@uvH`(sham empty-link-state)
      creator=miner
  ==
::
++  make-test-layer
  |=  [loc=layer-location ctrl=@p now=@da]
  ^-  layer-info
  =/  gen=block  (test-genesis-block now ctrl)
  :*  location=loc
      controller=ctrl
      link-state=empty-link-state
      chain-state=:*  blocks=(~(put by *(map @uvH block)) hash.gen gen)
                      block-height=(~(put by *(map @ud @uvH)) 0 hash.gen)
                      best-tip=hash.gen
                      difficulty=4
                  ==
      mempool=~
      active=%.y
  ==
::
++  make-test-state
  |=  now=@da
  ^-  myco-state
  :*  l1=(make-test-layer [%l1 ~] ~zod now)
      l2s=*(map @p layer-info)
      l3s=*(map @p layer-info)
      message-queue=~
      rpc-nonce=0
  ==
::
++  get-layer
  |=  [state=myco-state loc=layer-location]
  ^-  (unit layer-info)
  ?-  -.loc
    %l1  `l1.state
    %l2  (~(get by l2s.state) galaxy.loc)
    %l3  (~(get by l3s.state) star.loc)
  ==
::
++  put-layer
  |=  [state=myco-state loc=layer-location lyr=layer-info]
  ^-  myco-state
  ?-  -.loc
    %l1  state(l1 lyr)
    %l2  state(l2s (~(put by l2s.state) galaxy.loc lyr))
    %l3  state(l3s (~(put by l3s.state) star.loc lyr))
  ==
::
::  Tests
::
++  test-layer-creation
  =/  now=@da  *@da
  =/  state  (make-test-state now)
  ::  L1 should exist
  =/  l1  (get-layer state [%l1 ~])
  %+  expect-eq
    !>(%.y)
    !>(?=(^ l1))
::
++  test-l2-creation
  =/  now=@da  *@da
  =/  state  (make-test-state now)
  ::  Create L2 for galaxy ~zod
  =/  l2-loc=layer-location  [%l2 ~zod]
  =/  l2=layer-info  (make-test-layer l2-loc ~zod now)
  =/  new-state  (put-layer state l2-loc l2)
  ::  Should be retrievable
  =/  found  (get-layer new-state l2-loc)
  %+  expect-eq
    !>(%.y)
    !>(?=(^ found))
::
++  test-l3-creation
  =/  now=@da  *@da
  =/  state  (make-test-state now)
  ::  Create L3 for star ~marzod
  =/  l3-loc=layer-location  [%l3 ~marzod]
  =/  l3=layer-info  (make-test-layer l3-loc ~marzod now)
  =/  new-state  (put-layer state l3-loc l3)
  ::  Should be retrievable
  =/  found  (get-layer new-state l3-loc)
  %+  expect-eq
    !>(%.y)
    !>(?=(^ found))
::
++  test-genesis-state
  =/  now=@da  *@da
  =/  state  (make-test-state now)
  ::  L1 should have height 0
  %+  expect-eq
    !>(0)
    !>(current-height.link-state.l1.state)
::
++  test-empty-balances
  =/  now=@da  *@da
  =/  state  (make-test-state now)
  ::  Unknown account should have 0 balance
  =/  bal  (~(gut by balances.link-state.l1.state) ~zod 0)
  %+  expect-eq
    !>(0)
    !>(bal)
::
++  test-mempool-add
  =/  now=@da  *@da
  =/  state  (make-test-state now)
  ::  Add a transaction to L1 mempool
  =/  tx=link-transaction  [%transfer ~zod ~bus 100 0 0x0]
  =/  l1  l1.state
  =/  new-l1  l1(mempool [tx mempool.l1])
  =/  new-state  state(l1 new-l1)
  %+  expect-eq
    !>(1)
    !>((lent mempool.l1.new-state))
::
++  test-layer-location-key
  ::  Test layer-location discrimination
  %+  expect-eq
    !>(%.y)
    !>(?=(%l1 -.[%l1 ~]))
::
++  test-cross-layer-message-queue
  =/  now=@da  *@da
  =/  state  (make-test-state now)
  ::  Queue a cross-layer message
  =/  msg=layer-message
    :*  from-layer=[%l1 ~]
        to-layer=[%l2 ~zod]
        payload='hello'
    ==
  =/  new-state  state(message-queue [msg message-queue.state])
  %+  expect-eq
    !>(1)
    !>((lent message-queue.new-state))
::
++  test-transaction-types
  ::  Verify all transaction types can be constructed
  =/  t1=link-transaction  [%transfer ~zod ~bus 100 0 0x0]
  =/  t2=link-transaction  [%deploy ~zod 0 0 0 0x0]
  =/  t3=link-transaction  [%call ~zod ~bus 'method' 0 0 0x0]
  =/  t4=link-transaction  [%freeze ~zod 0 ~bus 0x0]
  =/  t5=link-transaction  [%thaw ~zod 0 0x0]
  =/  t6=link-transaction  [%melt ~zod 0 0 0 [%withdrawal ~bus]]
  =/  t7=link-transaction  [%spawn ~zod [*(map @p @ud) *(map @p @ud) *(map @p @ud) *(map @p @ux)]]
  =/  t8=link-transaction  [%dissolve [%l2 ~zod]]
  =/  t9=link-transaction  [%create-layer ~zod [%l2 ~bus]]
  ::  All should be discriminable
  %+  expect-eq
    !>(%.y)
    !>(&(?=(%transfer -.t1) ?=(%deploy -.t2) ?=(%call -.t3) ?=(%freeze -.t4) ?=(%thaw -.t5) ?=(%melt -.t6) ?=(%spawn -.t7) ?=(%dissolve -.t8) ?=(%create-layer -.t9)))
::
++  test-account-info-construction
  ::  Test info type construction
  =/  acct=info
    :*  frozen=%.n
        life=1
        pass=0x1234
        frozen-data=~
    ==
  %+  expect-eq
    !>(%.n)
    !>(frozen.acct)
::
++  test-frozen-data-construction
  ::  Test frozen-data construction
  =/  fd=frozen-data
    :*  amount=1.000
        layer=~zod
        freeze-block=42
        last-update=42
    ==
  %+  expect-eq
    !>(1.000)
    !>(amount.fd)
::
++  test-l2-destroy
  =/  now=@da  *@da
  =/  state  (make-test-state now)
  ::  Create then destroy L2
  =/  l2-loc=layer-location  [%l2 ~zod]
  =/  l2=layer-info  (make-test-layer l2-loc ~zod now)
  =/  state  (put-layer state l2-loc l2)
  ::  Verify exists
  =/  found  (get-layer state l2-loc)
  ?>  ?=(^ found)
  ::  Destroy
  =/  state  state(l2s (~(del by l2s.state) ~zod))
  =/  gone  (get-layer state l2-loc)
  %+  expect-eq
    !>(%.n)
    !>(?=(^ gone))
--
