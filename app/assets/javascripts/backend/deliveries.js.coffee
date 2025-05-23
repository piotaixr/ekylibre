((E, $) ->
  'use strict'

  $(document).behave "load click", "form label input[name='shipment[delivery_mode]']", ->
    input = $(this)
    if input.is(':checked')
      form = input.closest('form')
      form.find("input[name='shipment[delivery_mode]']").each ->
        $("#delivery-mode-#{$(this).val()}").hide()
      $("#delivery-mode-#{input.val()}").show()

  $(document).behave "load click", "form label input[name='delivery[mode]']", ->
    input = $(this)
    if input.is(':checked')
      form = input.closest('form')
      form.find("input[name='delivery[mode]']").each ->
        $("##{$(this).val()}").hide()
      $("##{input.val()}").show()

  # Manage fields filling in sales/purchases
  $(document).on "selector:set", "*[data-product-of-delivery-item]", (e, wasInitializing) ->
    element = $(this)
    options = element.data("product-of-delivery-item")
    product_id = element.selector('value')
    reg = new RegExp("\\bRECORD_ID\\b", "g")
    scope = options['scope']
    if product_id?
      item = element.closest(".delivery-item")
      $.ajax
        url: options.url.replace(reg, product_id)
        # get params from field sale_nature_id, planned_at from options
        data: {sale_nature_id: options.sale_nature_id, planned_at: options.planned_at}
        dataType: "json"
        success: (data, status, request) ->
          unit = item.find(".item-population-unit-name")
          if data.conditioning_unit_name
            unit.show()
            unit.html(data.conditioning_unit_name)
            item.attr('data-conditioning-unit-name', data.conditioning_unit_name)
          else if data.unit_name
            unit.html(data.unit_name)
            item.attr('data-unit-name', data.unit_name)
          else
            unit.html('#')
          set_default_sale_price(item, data.default_sale_price) if !wasInitializing
          if data.variant
            item.find(".item-variant-name").html(data.variant.name)
          pop = item.find(".item-population")
          total = item.find(".item-population-total")
          prefilled = element.closest('tr').find('.prefilled-conditioning')
          if prefilled.length > 0 && data.conditioning_coefficient
            prefilled_val = prefilled.data("conditioningQuantity") * prefilled.data("conditioningCoefficient") / data.conditioning_coefficient
            total.html(data.population)
            pop.val(prefilled_val)
          else if data.population
            total.html(data.population)
          else
            total.html('&ndash;')
            pop.attr('placeholder', '0')
          pop.attr('min', 0)
          pop.attr('max', data.population)
          if data.population_counting is 'unitary'
            pop.attr('disabled', 'disabled')
          else
            pop.removeAttr('disabled')

          if data.population_counting is 'integer'
            pop.attr('step', 1)
          else if data.population_counting is 'decimal'
            pop.removeAttr('step')

          item.find('*[data-when-item]').each ->
            if typeof data[$(this).data('when-item')] != "undefined"
              if typeof $(this).data('when-scope') == "undefined" or $(this).data('when-scope') == scope
                if typeof $(this).data("when-set-value") != "undefined"
                  if $(this).data("when-set-value") == "RECORD_VALUE"
                    newVal = data[$(this).data("when-item")]
                    newVal = newVal.toLowerCase() if typeof newVal == "string"

                    if $(this).is ":ui-selector"
                      $(this).selector("value", newVal)
                    else if this._flatpickr?
                      this._flatpickr.setDate(newVal)
                    else if $(this).is "select"
                      $(this).val(newVal).change()
                    else if $(this).is("input")
                      $(this).val(newVal)
                    else
                      $(this).html(newVal)

                    $(this).trigger 'change'

                    if typeof newVal == "string"
                      element = $(@)
                      element.is(":ui-mapeditor")
                      try
                        value = $.parseJSON(newVal)

                        if (value.geometries? and value.geometries.length > 0) || (value.coordinates? and value.coordinates.length > 0)
                          element.mapeditor "show", value
                          element.mapeditor "edit", value
                          try
                            element.mapeditor "view", "edit"

                      catch

                    if !$(this).is('select')
                      $(this).val(newVal)
                  else
                    $(this).val($(this).data("when-set-value"))

                if typeof $(this).data("when-prop-value") != "undefined"
                  $(this).prop($(this).data("when-prop-value"), true)

                if typeof $(this).data("when-display-value") != "undefined"
                  if $(this).data("when-display-value") == true
                    $(this).show()
                  else
                    $(this).hide()
                  $(this).trigger('visibility:change')

              if typeof $(this).data("when-filter-value") != "undefined"
                key_filter = Object.keys($(this).data('when-filter-value'))[0]
                scope = "scope[#{key_filter}]=#{data[$(this).data("when-item")]}"
                selector_url = $(this).data('selector')
                if selector_url.indexOf(scope) < 0
                  if selector_url.indexOf('?') < 0 then selector_url += '?' else selector_url += '&'
                  selector_url += scope
                $(this).attr('data-selector', selector_url)

            else
              if typeof $(this).data('when-scope') == "undefined" or $(this).data('when-scope') == scope
                if typeof $(this).data("when-prop-value") != "undefined"
                  $(this).prop($(this).data("when-prop-value"), false)

              if typeof $(this).data("when-display-value") != "undefined"
                if typeof $(this).data('when-scope') == "undefined" or $(this).data('when-scope') == scope
                  if $(this).data("when-display-value") == true
                    $(this).hide()
                  else
                    $(this).show()
                  $(this).trigger('visibility:change')


          # shape = item.find(options.population_field or ".item-shape")
          # if data.shape
          #   shape.show()
          # else
          #   shape.hide()

        error: (request, status, error) ->
          console.log("Error while retrieving price and tax fields content: #{error}")
    else
      console.warn "Cannot get product ID"

  set_default_sale_price = (item, default_price) ->
    if default_price
      item.find(".item-unit-pretax-sale-amount").val(default_price)
    else
      item.find(".item-unit-pretax-sale-amount").val(0.00)

  # Computes changes on items
  $(document).on "click", ".item-parted", (event) ->
    parted = $(this)
    item = parted.closest('.delivery-item')
    quantifier = item.find('.item-quantifier')
    if quantifier
      if parted.is(':checked')
        quantifier.removeClass('hidden')
      else
        quantifier.addClass('hidden')


  return
) ekylibre, jQuery
