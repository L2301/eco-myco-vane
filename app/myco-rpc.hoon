::  myco-rpc: Gall agent providing userspace access to %myco
::
::  Exposes %myco chain operations through pokes and subscriptions.
::  Acts as a bridge between userspace (Gall) and the %myco vane.
::
::  Poke actions:
::    %submit-tx     - Submit a transaction to a layer
::    %create-layer  - Create a new L2/L3 layer
::    %destroy-layer - Destroy an L2/L3 layer
::    %produce-block - Trigger block production
::    %rpc           - Execute an RPC query
::
::  Subscription paths:
::    /blocks/[layer]  - New block notifications
::    /txs/[layer]     - Transaction result notifications
::    /layers          - Layer lifecycle events
::
/-  *server
/+  default-agent, dbug
::
|%
::
+$  layer-location
  $%  [%l1 ~]
      [%l2 galaxy=@p]
      [%l3 star=@p]
  ==
::
+$  action
  $%  [%submit-tx loc=layer-location tx=*]
      [%create-layer loc=layer-location controller=@p]
      [%destroy-layer loc=layer-location]
      [%produce-block loc=layer-location]
      [%rpc loc=layer-location method=@t params=*]
  ==
::
+$  card  card:agent:gall
::
+$  agent-state
  $:  %0
      ::  Track which layers we've created
      layers=(set layer-location)
      ::  RPC nonce for tracking requests
      rpc-nonce=@ud
  ==
--
::
%-  agent:dbug
=|  state=agent-state
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)
::
++  on-init
  ^-  (quip card _this)
  ::  Initialize with L1 layer tracked
  [~ this(layers (~(put in layers.state) [%l1 ~]))]
::
++  on-save  !>(state)
::
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  [~ this(state !<(agent-state old-state))]
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?>  =(src.bowl our.bowl)  ::  Only local pokes
  ?+  mark  (on-poke:def mark vase)
    %myco-action
      =/  act=action  !<(action vase)
      ?-  -.act
        %submit-tx
          ::  Pass through to %myco vane
          =/  =note-arvo  [%m %submit-tx loc.act tx.act]
          :_  this
          :~  [%pass /tx/result %arvo note-arvo]
          ==
        ::
        %create-layer
          =/  =note-arvo  [%m %create-layer loc.act controller.act]
          :_  this(layers (~(put in layers.state) loc.act))
          :~  [%pass /layer/create %arvo note-arvo]
          ==
        ::
        %destroy-layer
          =/  =note-arvo  [%m %destroy-layer loc.act]
          :_  this(layers (~(del in layers.state) loc.act))
          :~  [%pass /layer/destroy %arvo note-arvo]
          ==
        ::
        %produce-block
          =/  =note-arvo  [%m %produce-block loc.act]
          :_  this
          :~  [%pass /block/produce %arvo note-arvo]
          ==
        ::
        %rpc
          =/  =note-arvo  [%m %rpc-request loc.act method.act params.act]
          :_  this(rpc-nonce.state +(rpc-nonce.state))
          :~  [%pass /rpc/(scot %ud rpc-nonce.state) %arvo note-arvo]
          ==
      ==
    ::
    %json
      ::  Handle JSON pokes from Eyre for HTTP RPC interface
      =/  jon=json  !<(json vase)
      ::  TODO: Parse JSON-RPC format and dispatch
      [~ this]
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
    [%blocks *]    [~ this]  ::  Subscribe to block notifications
    [%txs *]       [~ this]  ::  Subscribe to transaction results
    [%layers ~]    [~ this]  ::  Subscribe to layer lifecycle events
    [%rpc ~]       [~ this]  ::  Subscribe to RPC responses
  ==
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+  wire  [~ this]
    [%tx %result ~]
      ::  Transaction result from %myco vane
      :_  this
      :~  [%give %fact ~[/txs] %noun !>(sign-arvo)]
      ==
    ::
    [%block %produce ~]
      ::  Block production result
      :_  this
      :~  [%give %fact ~[/blocks] %noun !>(sign-arvo)]
      ==
    ::
    [%layer *]
      ::  Layer lifecycle event
      :_  this
      :~  [%give %fact ~[/layers] %noun !>(sign-arvo)]
      ==
    ::
    [%rpc *]
      ::  RPC response
      :_  this
      :~  [%give %fact ~[/rpc] %noun !>(sign-arvo)]
      ==
  ==
::
++  on-agent  on-agent:def
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  ~
    ::  /x/layers -> set of tracked layers
    [%x %layers ~]
      ``[%noun !>(layers.state)]
    ::
    ::  /x/l1/balance/ship -> scry through to %myco
    [%x %l1 %balance @t ~]
      =/  who=@p  (slav %p i.t.t.t.path)
      ::  Scry into %myco vane: .^(@ %mx /=//=/l1/balance/(scot %p who))
      ~
    ::
    ::  /x/rpc-nonce -> current RPC counter
    [%x %rpc-nonce ~]
      ``[%atom !>(rpc-nonce.state)]
  ==
::
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
