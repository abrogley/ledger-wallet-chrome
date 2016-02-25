class @WalletNavigationController extends ledger.common.ActionBarNavigationController

  _menuItemBaseUrl: {
#    '/wallet/send/': '#send-item'
#    '/wallet/receive/': '#receive-item'
#    '/wallet/accounts/': '#accounts-item'
#    '/wallet/signout/': '#signout-item'
    '/wallet/accounts/index' : '#accounts-item'
  }
  view:
    balanceValue: '#balance_value'
    reloadIcon: '#reload_icon'
    currencyContainer: '#currency_container'

  constructor: () ->
    super
    ledger.application.router.on 'routed', @_onRoutedUrl

  _onRoutedUrl: (event, data) ->
    {url} = data
    @updateMenu url

  onAfterRender: () ->
    super
    url = ledger.application.router.currentUrl
    @updateMenu url
    @_listenBalanceEvents()
    @_listenSynchronizationEvents()
    @_listenCountervalueEvents()

  updateMenu: (url) ->
    for baseUrl, itemSelector of @_menuItemBaseUrl
      if _.str.startsWith url, baseUrl
        menuItem = @select(itemSelector)
        unless menuItem.hasClass 'selected'
          previousItem = @select('li.selected')
          if previousItem.length > 0
            previousSelector = previousItem.find('.selector')
            color = previousSelector.css('background-color')
            previousItem.removeClass 'selected'
            previousSelector.css('background-color', color)
            previousItem.find('.selector').animate {bottom: '-10px'}, 200,  ->
              previousSelector.css('background-color', '')
              previousSelector.css('bottom', '0px')
            menuItem.addClass 'selected'
            newSelector = menuItem.find '.selector'
            newSelector.css('bottom', '-10px')
            newSelector.animate {bottom: '0px'}, 200
          else
            menuItem.addClass 'selected'
        break

  onDetach: ->
    super
    ledger.app.off 'wallet:balance:changed', @_updateBalanceValue
    ledger.app.off 'wallet:balance:changed wallet:balance:unchanged wallet:balance:failed wallet:operations:sync:failed wallet:operations:sync:done', @_onSynchronizationStateChanged
    ledger.tasks.OperationsSynchronizationTask.instance.off 'start stop', @_onSynchronizationStateChanged
    ledger.preferences.instance?.off 'currencyActive:changed', @_updateCountervalue
    ledger.app.off 'wallet:balance:changed', @_updateCountervalue

  _listenBalanceEvents: ->
    # fetch balances
    @_updateBalanceValue()
    # listen events
    ledger.app.on 'wallet:balance:changed', @_updateBalanceValue

  _updateBalanceValue: (balance) ->
    @view.balanceValue.text ledger.formatters.fromValue(Wallet.instance.getBalance().wallet.total)

  _listenSynchronizationEvents: ->
    @view.reloadIcon.on 'click', =>
      ledger.tasks.TickerTask.instance.updateTicker()
      ledger.tasks.OperationsConsumptionTask.instance.startIfNeccessary()
      ledger.storage.sync.pull()
      _.defer @_updateReloadIconState
    ledger.app.on 'wallet:balance:changed wallet:balance:unchanged wallet:balance:failed wallet:operations:sync:failed wallet:operations:sync:done', @_onSynchronizationStateChanged
    ledger.tasks.OperationsSynchronizationTask.instance.on 'start stop', @_onSynchronizationStateChanged
    @_updateReloadIconState()

  _onSynchronizationStateChanged: ->
    _.defer @_updateReloadIconState

  _updateReloadIconState: =>
    if @_isSynchronizationRunning()
      @view.reloadIcon.addClass 'spinning'
    else
      @view.reloadIcon.removeClass 'spinning'

  _isSynchronizationRunning: ->
    return ledger.tasks.OperationsConsumptionTask.instance.isRunning()

  _listenCountervalueEvents: ->
    # update counter value
    @_updateCountervalue()
    # listen countervalue event
    ledger.preferences.instance.on 'currencyActive:changed', @_updateCountervalue
    ledger.app.on 'wallet:balance:changed', @_updateCountervalue

  _updateCountervalue: ->
    @view.currencyContainer.removeAttr 'data-countervalue'
    @view.currencyContainer.empty()
    if ledger.preferences.instance.isCurrencyActive()
      @view.currencyContainer.attr 'data-countervalue', Wallet.instance.getBalance().wallet.total
    else
      @view.currencyContainer.text t('wallet.top_menu.balance')

  getActionBarDrawer: ->
    @_actionBarDrawer ||= _.extend new ledger.common.ActionBarNavigationController.ActionBar.Drawer(),
      createBreadcrumbPartView: (title, url, position, length) =>
        view = $("<span>#{t(title)}</span>")
        view.addClass("breadcrumb-root") if position is 0
        url += "/index" if position is 0
        view.attr('data-href', url) if not _.isEmpty(url) and position < length - 1 and @topViewController().routedUrl isnt url
        view

      createBreadcrumbSeparatorView: (position) => $("<span>&nbsp;&nbsp;>&nbsp;&nbsp;</span>")

      createActionView: (title, icon, url, position, length) =>
        view = $("<span><i class=\"fa #{icon}\"></i>#{t(title)}</span>")
        view.attr('data-href', url)
        view

      createActionSeparatorView: (position) => null

      getActionBarHolderView: => @select('.action-bar-holder')

      getBreadCrumbHolderView: => @select('.breadcrumb-holder')

      getActionsHolderView: => @select('.actions-holder')