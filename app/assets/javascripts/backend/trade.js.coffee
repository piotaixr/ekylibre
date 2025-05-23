((E, $) ->
  'use strict'

  # Toggle annotation widget
  $(document).on "click", "a[data-annotate]", (event) ->
    link = $(this)
    scope = $("html")
    if link.data("use-closest")
      scope = link.closest(link.data("use-closest"))
    link.hide()
    annotation = scope.find(link.data('annotate'))
    annotation.show()
    autosize annotation.find("textarea").focus()
    return false


  # Manage fields filling in sales/purchases
  $(document).on "selector:change", "*[data-variant-of-deal-item]", (_event, _value, is_initialization) ->
    E.trade.updateValues($(this), is_initialization)


  E.trade =

    updateValues: ($element, is_initialization) ->
      options = $element.data("variant-of-deal-item")
      variant_id = $element.selector('value')
      reg = new RegExp("\\bRECORD_ID\\b", "g")
      form = $element.closest('form')
      params = {}
      # TODO So so bad
      form.find('#sale_client_id, #purchase_supplier_id, #sale_address_id, #purchase_address_id').each ->
        selector = $(this)
        value = selector.selector('value')
        params[selector.attr('id')] = value if value?
      $conditioningSelector = $element.closest($element.data('parent')).find($element.data('filter-unroll'))
      if $conditioningSelector[0] != $conditioningSelector.context && !is_initialization
        $conditioningSelector.closest('.selector').find('.selector-value').attr('value', '')
        $conditioningSelector.val('')
      if $conditioningSelector.length
        conditioningId = $conditioningSelector.first().selector('value')
        params['conditioning_id'] = conditioningId if conditioningId
      params['reference_date'] = form.find('[data-deal-reference-date]').val()

      if variant_id?
        item = $element.closest("*[data-trade-item]")
        $.ajax
          url: options.url.replace(reg, variant_id)
          data: params
          dataType: "json"
          success: (data, status, request) ->
            # Update fields
            if data.name
              item.find(options.label_field or ".label").val(data.name)

            if data.depreciable
              item.find('.fixed-asset').show()
              preexistingAsset = item.find(".sale_items_preexisting_asset input[type='checkbox']").prop('checked')
              item.find('#new_asset').hide() if preexistingAsset
            else
              item.find('.fixed-asset').hide()

            if data.subscription?
              if data.subscription.nature_name?
                item.find('.subscription_nature_name').html(data.subscription.nature_name)
              if data.subscription.started_on?
                item.find('.subscription_started_on').val(data.subscription.started_on)
              if data.subscription.stopped_on?
                item.find('.subscription_stopped_on').val(data.subscription.stopped_on)
              if data.subscription.address_id?
                select = item.find('.subscription_address_id').first()
                select.selector('value', data.subscription.address_id)
              item.find('.subscription').show()
            else
              item.find('.subscription').hide()
              select = item.find('.subscription_address_id').first()
              select.selector('clear')
              item.find('.subscription_started_on').val('')
              item.find('.subscription_stopped_on').val('')

            tradeType = item.data('tradeItem')
            $taxSelector = item.find("*[data-trade-component='tax']")
            if ['purchase', 'sale'].includes(tradeType)
              tax_ids =  data.tax_ids[tradeType]
            if tax_ids?
              E.trade._handleTaxSelectorOptions($taxSelector, tax_ids)

            if !is_initialization && unit = data.unit
              if unit.name
                item.find(options.unit_name_tag or ".unit-name").html(data.name)
              if unit.conditioning_id
                conditioning_selector_element = item.find("[id$='conditioning_unit_id']")
                if !conditioning_selector_element.val()
                  conditioning_selector = conditioning_selector_element.data('ui-selector')
                  conditioning_selector.value(unit.conditioning_id, true)
              input = item.find(options.unit_pretax_amount_field or "*[data-trade-component='unit_pretax_amount']")
              if unit.pretax_amount?
                input.val(unit.pretax_amount)
                input.trigger('unit-value:change')
              else if input.val() is ""
                input.val(0)

              input = item.find(options.unit_amount_field or "*[data-trade-component='unit_amount']")
              if unit.amount?
                input.val(unit.amount)
              else if input.val() is ""
                input.val(0)

              # Compute totals
              E.trade.updateUnitPretaxAmount(item)
              E.toggleValidateButton(item, false)

              if tax_ids?
                E.trade._handleTaxSelectorValue($taxSelector, tax_ids)

            # Compute totals
            if ['change', 'readystatechange'].includes event.type
              E.trade.updateUnitPretaxAmount(item)

          error: (request, status, error) ->
            console.log("Error while retrieving price and tax fields content: #{error}")
      else
        console.warn "Cannot get variant ID"

    _handleTaxSelectorValue: ($taxSelector, tax_ids) ->
      if tax_ids.length > 0
        $taxSelector.val(tax_ids[0])

    _handleTaxSelectorOptions: ($taxSelector, tax_ids) ->
      if tax_ids.length > 1
        $taxSelector.children('option').toArray().map((option) ->
          $(option).show()
          if !tax_ids.includes(parseInt(option.value))
            $(option).hide()
        )

    round: (value, digits) ->
      magnitude = Math.pow(10, digits)
      # console.log value, magnitude, value * magnitude, Math.round(value * magnitude), (Math.round(value * magnitude) / magnitude), (Math.round(value * magnitude) / magnitude).toFixed(digits)
      return (Math.round(value * magnitude) / magnitude).toFixed(digits)

    # Compute other amounts from unit pretax amount
    updateUnitPretaxAmount: (item) ->
      values = E.trade.itemValues(item)
      updates = {}
      # Compute pretax_amount
      updates.pretax_amount = values.unit_pretax_amount * values.quantity * (100.0 - values.reduction_percentage) / 100.0
      # Compute amount
      updates.amount = E.trade.round(updates.pretax_amount * values.tax, 2)
      # Round pretax amount
      updates.pretax_amount = E.trade.round(updates.pretax_amount, 2)
      E.trade.itemValues(item, updates)

    # Compute other amounts from pretax amount
    updatePretaxAmount: (item) ->
      values = E.trade.itemValues(item)
      updates = {}
      # Compute unit_pretax_amount
      updates.unit_pretax_amount = E.trade.round(values.pretax_amount / (values.quantity * (100.0 - values.reduction_percentage) / 100.0), 2)
      # Compute amount
      updates.amount = E.trade.round(values.pretax_amount * values.tax, 2)
      E.trade.itemValues(item, updates)

    # Compute other amounts from amount
    updateAmount: (item) ->
      values = E.trade.itemValues(item)
      updates = {}
      # Compute pretax_amount
      updates.pretax_amount = values.amount / values.tax
      # Compute unit_pretax_amount
      updates.unit_pretax_amount = E.trade.round(updates.pretax_amount / (values.quantity * (100.0 - values.reduction_percentage) / 100.0), 2)
      # Round pretax amount
      updates.pretax_amount = E.trade.round(updates.pretax_amount, 2)
      E.trade.itemValues(item, updates)

    # Compute other amounts from amount
    updateCreditedQuantity: (item) ->
      values = E.trade.itemValues(item)
      updates = {}
      # Compute pretax_amount
      updates.pretax_amount = -1 * values.unit_pretax_amount * values.credited_quantity * (100.0 - values.reduction_percentage) / 100.0
      # Compute unit_pretax_amount
      updates.amount = E.trade.round(updates.pretax_amount * values.tax, 2)
      # Round pretax amount
      updates.pretax_amount = E.trade.round(updates.pretax_amount, 2)
      E.trade.itemValues(item, updates)

    # Compute other amounts from pretax amount
    updateCreditedPretaxAmount: (item) ->
      values = E.trade.itemValues(item)
      updates = {}
      # Compute credited quantity
      updates.unit_pretax_amount = -(E.trade.round(values.pretax_amount / (values.credited_quantity * (100.0 - values.reduction_percentage) / 100.0), 2))
      # Compute amount
      updates.amount = E.trade.round(values.pretax_amount * values.tax, 2)
      E.trade.itemValues(item, updates)

    # Compute other amounts from unit pretax amount
    updateCreditedAmount: (item) ->
      values = E.trade.itemValues(item)
      updates = {}
      # Compute pretax_amount
      updates.pretax_amount = values.amount / values.tax
      # Compute credited quantity
      updates.unit_pretax_amount = -(E.trade.round(values.pretax_amount / (values.credited_quantity * (100.0 - values.reduction_percentage) / 100.0), 2))
      # Compute amount
      # Round pretax amount
      updates.pretax_amount = E.trade.round(updates.pretax_amount, 2)
      E.trade.itemValues(item, updates)

    find: (item, name) ->
      item.find("*[data-trade-component='#{name}']")

    itemValues: (item, updates = null) ->
      if updates is null
        values =
          unit_pretax_amount: E.trade.find(item, "unit_pretax_amount").numericalValue()
          quantity: E.trade.find(item, "quantity").numericalValue()
          credited_quantity: E.trade.find(item, "credited_quantity").numericalValue()
          reduction_percentage: E.trade.find(item, "reduction_percentage").numericalValue()
          tax: E.trade.find(item, "tax").numericalValue()
          pretax_amount: E.trade.find(item, "pretax_amount").numericalValue()
          amount: E.trade.find(item, "amount").numericalValue()
        return values
      else
        for key, value of updates
          E.trade.find(item, key).numericalValue(value)

  E.purchasing =

    # Compute what have to be computed
    compute: (item, changedComponent) ->
      component = changedComponent.data("trade-component")
      switch component
        when 'unit_pretax_amount', 'quantity', 'reduction_percentage', 'tax'
          E.trade.updateUnitPretaxAmount(item)
        when 'pretax_amount'
          E.trade.updatePretaxAmount(item)
        when 'amount', 'conditionning', 'conditionning_quantity'
          E.trade.updateAmount(item) if item.closest('tbody').is('[data-trade-type="quick_affair"]') # Change THIS
        else
          console.error "Unknown component: #{component}"

  # Computes changes on items
  $(document).on "keyup change", "form *[data-trade-item='purchase'] *[data-trade-component]", (event) ->
    component = $(this)
    E.purchasing.compute component.closest("*[data-trade-item]"), component

  E.selling =

    # Compute what have to be computed
    compute: (item, changedComponent) ->
      component = changedComponent.data("trade-component")
      unless component in ['unit_pretax_amount', 'pretax_amount', 'amount']
        component = changedComponent.closest('*[data-trade-item]').find('*[data-compute-from-updater]').val()
      switch component
        when 'unit_pretax_amount'
          E.trade.updateUnitPretaxAmount(item)
        when 'pretax_amount'
          E.trade.updatePretaxAmount(item)
        when 'amount'
          E.trade.updateAmount(item)
        else
          console.error "Unknown component: #{component}"

  # Computes changes on items
  $(document).on "keyup change", "form *[data-trade-item='sale'] *[data-trade-component]", (event) ->
    component = $(this)
    E.selling.compute component.closest("*[data-trade-item]"), component


  $(document).on "change", "*[data-compute-from]", (e) ->
    $(e.currentTarget).closest('*[data-trade-item]').find('*[data-compute-from-updater]').val($(e.currentTarget).data('compute-from'))


  # Sale crediting workflow
  E.crediting =
    # Compute what have to be computed
    compute: (item, changedComponent) ->
      component = changedComponent.data("trade-component")
      switch component
        when 'credited_quantity'
          E.trade.updateCreditedQuantity(item)
        when 'pretax_amount'
          E.trade.updateCreditedPretaxAmount(item)
        when 'amount'
          E.trade.updateCreditedAmount(item)
        else
          console.error "Unknown component: #{component}"

  # Computes changes on items
  $(document).on "keyup change", "form *[data-trade-item='crediting'] *[data-trade-component]", (event) ->
    component = $(this)
    E.crediting.compute component.closest("*[data-trade-item]"), component

  return
) ekylibre, jQuery
