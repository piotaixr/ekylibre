# This module permits to execute an procedure to generate operations
# with the user interaction.

((E, $) ->
  'use strict'

  PLANNED_REALISED_ACCEPTED_GAP = { intervention_doer: 1.2, intervention_tool: 1.2 , intervention_input: 1.2}

  no_submit = => false

  E.value = (element) ->
    if element.is(":ui-selector")
      return element.selector("value")
    else
      return element.val()

  # Interventions permit to enhances data input through context computation
  # The concept is: When an update is done, we ask server which are the impact on
  # other fields and on updater itself if necessary
  E.interventions =
    updateProcedureLevelAttributes: (form, attributes) ->
      for name, properties of attributes
        parameterContainer = $("[data-intervention-parameter='#{name}']").parent('.nested-association')
        if properties.display
          statusDisplay = parameterContainer.find(".display-info")
          statusDisplay.find(" .status")
                       .attr('data-display-status', properties.display)
          statusDisplay.show()

    handleComponents: (form, attributes, prefix = '') ->
      for name, value of attributes
        subprefix = prefix + name
        if /\w+_attributes$/.test(name)
          for id, attrs of value
            E.interventions.handleComponents(form, attrs, subprefix + '_' + id + '_')
        else
          input = form.find("##{prefix}component_id")
          unrollPath = input.attr('data-selector')
          if unrollPath
            assemblyId = attributes["assembly_id"]
            if typeof(assemblyId) == 'undefined' or assemblyId is null
              assemblyId = "nil"
            componentReg = /(unroll\?.*scope.*components_of_product[^=]*)=([^&]*)(&?.*)/
            oldAssemblyId = unrollPath.match(componentReg)[2]
            unrollPath = unrollPath.replace(componentReg, "$1=#{assemblyId}$3")
            input.attr('data-selector', unrollPath)
            if assemblyId.toString() != oldAssemblyId.toString()
              console.log "CLEAR"
              $(input).val('')


    handleDynascope: (form, attributes, prefix = '') ->
      for name, value of attributes
        subprefix = prefix + name
        if /\w+_attributes$/.test(name)
          for id, attrs of value
            E.interventions.handleDynascope(form, attrs, subprefix + '_' + id + '_')
        else
          if name is 'attributes' and value?
            # for each attribute
            for k, v of value
              input = form.find("##{prefix}#{k}")
              unrollPath = input.attr('data-selector')
              if unrollPath
                # for each scope
                for scopeKey, scopeValue of v.dynascope

                  scopeReg = ///
                  (.* #root
                  unroll\\?.*scope.*#{scopeKey}[^=]*) # current scope
                  = ([^&]*) # current value to change
                  (&?.*)
                  ///
                  unrollPath = unrollPath.replace(scopeReg, "$1=#{encodeURIComponent(scopeValue)}$3")
                input.attr('data-selector', unrollPath)

    toggleHandlers: (form, attributes, prefix = '') ->
      for name, value of attributes
        subprefix = prefix + name
        if /\w+_attributes$/.test(name)
          for id, attrs of value
            E.interventions.toggleHandlers(form, attrs, subprefix + '_' + id + '_')
        else
          select = form.find("##{prefix}quantity_handler")
          console.warn "Cannot find ##{prefix}quantity_handler <select>" unless select.length > 0
          option = select.find("option[value='#{name}']")
          console.warn "Cannot find option #{name} of ##{prefix}quantity_handler <select>" unless option.length > 0
          if value
            option.show()
          else
            option.hide()

    unserializeRecord: (form, attributes, prefix = '', updater_id = null) ->
      for name, value of attributes
        subprefix = prefix + name
        if subprefix is updater_id
          # Nothing to update
          # console.warn "Nothing to do with #{subprefix}"
        else if /\w+_attributes$/.test(name)
          E.interventions.unserializeList(form, value, subprefix + '_', updater_id)
        else
#          console.log subprefix
          form.find("##{subprefix}").each (index) ->
            if 'errors' in Object.keys(attributes)
              $(this).parent('.nested-fields').find(".errors *").hide()
              for error, message of attributes.errors
                errorMessage = $(this).parent('.nested-fields').find(".errors .#{error}")
                if typeof(message) != 'undefined'
                  errorMessage.show()
            element = $(this)
            if element.is(':ui-selector')
              if value != element.selector('value')
                if value is null
                  console.log "Clear ##{subprefix}"
                  element.selector('clear')
                else
                  console.log "Updates ##{subprefix} with: ", value
                  element.selector('value', value)
            else if element.is(":ui-mapeditor")
              value = $.parseJSON(value)
              if (value.geometries? and value.geometries.length > 0) || (value.coordinates? and value.coordinates.length > 0)
                element.mapeditor "edit", value
                try
                  element.mapeditor "view", "edit"
            else if element.is('select')
              v = if value == null then '' else value
              element.find("option[value='#{v}']")[0].selected = true
            else
              valueType = typeof value
              update = true
              update = false if value is null and element.val() is ""
              if valueType == "number"
                # When element doesn't have any value, element.numericalValue() == 0
                update = false if value == element.numericalValue() && element.numericalValue() != 0
              else
                update = false if value == element.val()
              if update
                console.log "Updates ##{subprefix} with: ", value
                element.val(value)
                element.next('input.flatpickr-input').val(moment(value).format('DD-MM-YYYY HH:mm')) if element.hasClass('flatpickr-input')
                element.trigger('intervention-field:value-updated')

    unserializeList: (form, list, prefix = '', updater_id) ->
      for id, attributes of list
        E.interventions.unserializeRecord(form, attributes, prefix + id + '_', updater_id)

    updateAvailabilityInstant: (newTime) ->
      return if newTime == ''
      $("input.scoped-parameter").each (index, item) ->
        scopeUri = decodeURI($(item).data("selector"))
        itemIsTarget = /targets/.test($(item).data('intervention-updater'))
        if itemIsTarget
          re =  /(scope\[availables\]\[\]\[at\]=)(.*?)(&)(scope\[land_parcel_alive\]\[\]\[at\]=)(.*?)(&)/
          scopeUri = scopeUri.replace(re, "$1" + moment(newTime).format('YYYY-MM-DD HH:mm') + "$3" + "$4" + moment(newTime).format('YYYY-MM-DD HH:mm') + "$6")
        else
          re =  /(scope\[availables\]\[\]\[at\]=)(.*?)(&)/
          scopeUri = scopeUri.replace(re, "$1" + moment(newTime).format('YYYY-MM-DD HH:mm') + "$3")
        $(item).attr("data-selector", encodeURI(scopeUri))

    _setWaiting: (form, computing) ->
      computing.prop 'state', 'waiting'
      form.on('submit', no_submit)
      form.find('.form-actions input[type="submit"]').prop 'disabled', true

    _setReady: (form, computing) ->
      computing.prop 'state', 'ready'
      form.off('submit', no_submit)
      form.find('.form-actions input[type="submit"]').prop 'disabled', false

    # Ask for a refresh of values depending on given update
    refresh: (updater, options = {}) ->
      unless updater?
        console.error 'Missing updater'
        return false
      updaterId = updater.data('intervention-updater')
      unless updaterId?
        console.warn 'No updater id, so no refresh'
        return false
      form = updater.closest('form')
      form.find("input[name='updater']").val(updaterId)
      computing = form.find('*[data-procedure]').first()
      unless computing.length > 0
        console.error 'Cannot procedure element where compute URL is defined'
        return false
      if computing.prop('state') isnt 'waiting'
        $.ajax
          url: computing.data('procedure')
          type: "PATCH"
          data: form.serialize()
          beforeSend: ->
            E.interventions._setWaiting(form, computing)
          error: (request, status, error) ->
            E.interventions._setReady(form, computing)
            false
          success: (data, status, request) ->
            console.group('Unserialize intervention updated by ' + updaterId)
            # Updates elements with new values
            E.interventions.toggleHandlers(form, data.handlers, 'intervention_')
            E.interventions.handleComponents(form, data.intervention, 'intervention_', data.updater_id)
            E.interventions.handleDynascope(form, data.intervention, 'intervention_', data.updater_id)
            E.interventions.unserializeRecord(form, data.intervention, 'intervention_', data.updater_id)
            E.interventions.updateProcedureLevelAttributes(form, data.procedure_states)
            E.interventions._setReady(form, computing)
            options.success.call(this, data, status, request) if options.success?
            console.groupEnd()

            if options['display_cost']
              targettedElement = options['targetted_element']
              parentBlock = $(targettedElement).closest('.nested-product-parameter')
              quantity = $(parentBlock).find('input[data-intervention-field="quantity-value"]').val()
              unitName = $(parentBlock).find('select[data-intervention-field="quantity-handler"]').val()
              E.interventionForm.displayCost(targettedElement, quantity, unitName)

            isUsingMap = $("[data-intervention-updater$='working_zone_area_value']").length == 0
            isTargetProductUpdate = data.updater_id.includes('targets_attributes') && data.updater_id.includes('product_id')

            if isUsingMap && isTargetProductUpdate
              refreshQuantityWithDelay()

    hideKujakuFilters: (hideFilters) ->
      if hideFilters
        $('.feathers input[name*="nature"], .feathers input[name*="state"]').closest('.feather').hide()
      else
        $('.feathers input[name*="nature"], .feathers input[name*="state"]').closest('.feather').show()

    showInterventionParticipationsModal: ->
      $(document).on 'click', '.has-intervention-participations', (event) ->

        targetted_element = $(event.target)
        intervention_id = $('input[name="intervention_id"]').val()
        product_id = $(event.target).closest('.nested-product-parameter').find(".selector .selector-value").val()
        existingParticipation = $('.intervention-participation[data-product-id="' + product_id + '"]').val()
        participations = $('intervention_participation')
        interventionStartedAt = $('#intervention_working_periods_attributes_0_started_at').val()

        participations = []

        doersParameters = targetted_element.closest(".nested-parameters").siblings(".nested-doers")
        tractorsParameters = targetted_element.closest('.nested-tractor').closest('.nested-tools')
        doersToolsParameters = $('.nested-parameters.nested-doers, .nested-parameters.nested-tools')

        if doersParameters.length > 0
          interventionParticipations = doersParameters.find('.intervention-participation')
        else if tractorsParameters.length > 0
          interventionParticipations = doersToolsParameters.find('.nested-product-parameter.nested-driver, .nested-product-parameter.nested-tractor').find('.intervention-participation')
        else
          interventionParticipations = doersToolsParameters.find('.nested-product-parameter').not('.nested-tractor').find('.intervention-participation')

        interventionParticipations.each ->
          participations.push($(this).val())

        autoCalculMode = $('#intervention_auto_calculate_working_periods').val()

        datas = {}
        datas['intervention_id'] = intervention_id
        datas['product_id'] = product_id
        datas['existing_participation'] = existingParticipation
        datas['participations'] = participations
        datas['intervention_started_at'] = interventionStartedAt
        datas['auto_calcul_mode'] = autoCalculMode
        datas['intervention_form'] = $("#new_intervention").serialize()

        $.post
          url: "/backend/intervention_participations/participations_modal",
          data: datas
          success: (data, status, request) ->
            @workingTimesModal = new ekylibre.modal('#working_times')
            @workingTimesModal.removeModalContent()
            @workingTimesModal.getModalContent().append(data)
            @workingTimesModal.getModal().modal 'show'


    addLazyLoading: (taskboard, params) ->
      loadContent = false
      currentPage = 1
      taskHeight = 60
      halfTaskList = 12

      $('#core').scroll ->
        if !loadContent && $('#core').scrollTop() > (currentPage * halfTaskList) * taskHeight
          currentPage++
          params['page'] = currentPage

          loadContent = true
          if $('#compare-planned-and-realised').attr('checked')
            comparePlannedRealised = true

          $.ajax
            url: "/backend/interventions/change_page",
            data: { interventions_taskboard: params, compare_planned_realised: comparePlannedRealised }
            success: (data, status, request) ->
              loadContent = false
              taskboard.addTaskClickEvent()

    generateItemsArrayFromId: (input)->
      intervention_id = input.parents().find('#intervention_id').val() if input.parents().find('#intervention_id').val().length > 0
      purchase_id = input.parent().find('.selector-value').val()
      $('.purchase-items-array').empty()
      return unless input.selector('value')

      itemHeader = []
      itemHeader.push("<span class='header-name'>Article</span>")
      itemHeader.push("<span class='header-quantity'>Quantité</span>")
      itemHeader.push("<span class='header-conditioning-unit'></span>")
      itemHeader.push("<span class='header-unit-pretax-amount'>PU HT</span>")
      itemHeader.push("<span class='header-amount'>Prix total</span>")
      $('.purchase-items-array').append("<li class='header-line'>" + itemHeader.join('') + "</li>")
      $.get
        url: "/backend/interventions/purchase_order_items"
        data: { purchase_order_id: purchase_id, intervention_id: intervention_id}
        success: (data, status, request) ->
          for item, index in data.items
            itemLine = []
            if intervention_id? && item.is_reception
              itemLine.push("<span class='item-id'><input name='intervention[receptions_attributes][0][items_attributes][#{-index}][id]' value='#{item.id}' type='hidden'></input></span>")
            itemLine.push("<span class='item-name'><input name='intervention[receptions_attributes][0][items_attributes][#{-index}][variant_id]' value='#{item.variant_id}' type='hidden'></input>" + item.name + "</span>")
            itemLine.push("<span class='item-quantity'><input type='number' class='input-quantity' name='intervention[receptions_attributes][0][items_attributes][#{-index}][conditioning_quantity]' value ='#{item.quantity}'></input></span>")
            itemLine.push("<span class='item-conditioning-unit'><input name='intervention[receptions_attributes][0][items_attributes][#{-index}][conditioning_unit_id]' value='#{item.conditioning_unit_id}' type='hidden'></input>#{item.conditioning_unit_name}</span>")
            itemLine.push("<span class='item-unit-pretax-amount'>" + item.unit_pretax_amount + "</span>")
            itemLine.push("<span class='item-amount'>" + item.unit_pretax_amount * item.quantity +  "</span>")
            itemLine.push("<span class='item-role'><input name='intervention[receptions_attributes][0][items_attributes][#{-index}][role]' value='#{item.role}' type='hidden'></input></span>")
            itemLine.push("<span class='item-purchase-order-item-id'><input name='intervention[receptions_attributes][0][items_attributes][#{-index}][purchase_order_item_id]' value='#{item.purchase_order_item}' type='hidden'></input></span>")
            $('.purchase-items-array').append("<li class='item-line'>" + itemLine.join('') + "</li>")
            if $('.cant-be-update').length > 0
              $('.purchase-items-array').find('.item-line input').attr('disabled',true)

    updateTotalAmount: (input) ->
      quantity = parseFloat(input.val())
      totalAmount = quantity * parseFloat(input.parents('li.item-line').find('.item-unit-pretax-amount').text())
      input.parents('li.item-line').find('.item-amount').html(totalAmount.toFixed(2))

    isPurchaseOrderSelectorEnabled: (input) ->
      purchaseInput = input.parents('.fieldset-fields').find('.reception-purchase')
      if input.val().length == 0
        purchaseInput.attr("disabled",true)
      else
        purchaseInput.attr("disabled",false)
      if $('.cant-be-update').length > 0
        input.parents('.fieldset-fields').find('input').attr('disabled', true)

  ##############################################################################
  # Triggers
  #
  $(document).on 'cocoon:after-insert', (e, i) ->
    $('input[data-map-editor]').each ->
      $(this).mapeditor()
    $('#working-periods *[data-intervention-updater]').each ->
      E.interventions.refresh $(this),
        success: (stat, status, request) ->
          E.interventions.updateAvailabilityInstant($(".nested-fields.working-period:first-child input.intervention-started-at").first().val())

  $(document).on 'cocoon:after-remove', (e, i) ->
    $('#working-periods *[data-intervention-updater]').each ->
      E.interventions.refresh $(this)

  $(document).on 'mapchange', '*[data-intervention-updater]', ->
    $(this).each ->
      E.interventions.refresh $(this)

  $(document).ready ->
    updaters = $('*[data-intervention-updater]')
    # Previous system was calling refresh method with each updater, we now use first updater because the returned values were all the same (except for a very specific case which we avoid by selecting first updater)
    updater = updaters[0]
    E.interventions.refresh $(updater)
    # Stopped_at is not automaticaly updated to started_at + 1 hour if stopped_at is manually updated
    E.interventionForm.setupStoppedAtInputBehaviour()

  $(document).on 'selector:change', '*[data-intervention-updater]', (event, _element, wasInitializing) ->
      return if wasInitializing

      $(this).each ->
        options = {}
        options['display_cost'] = true
        options['targetted_element'] = $(event.target)

        E.interventions.refresh $(this), options

  $(document).on 'keyup', 'input[data-selector]', (e) ->
    $(this).each ->
      E.interventions.refresh $(this)

  $(document).on 'keyup change', 'input[data-intervention-updater]:not([data-selector], .flatpickr-input)', (event) ->
    $(this).each ->
      options = {}
      options['display_cost'] = true
      options['targetted_element'] = $(event.target)

      E.interventions.refresh $(this), options

  $(document).on 'keyup change', 'select[data-intervention-updater]', (event) ->
    $(this).each ->
      options = {}
      options['display_cost'] = true
      options['targetted_element'] = $(event.target)

      E.interventions.refresh $(this), options

  $(document).on 'selector:change', '.intervention_tools_product .selector-search', (event) ->
    toolId = $(event.target).closest('.selector').find('.selector-value').val()

    $.ajax
      url: "/backend/products/indicators/#{ toolId }/variable_indicators"
      success: (data, status, request) ->
        return if data['is_hour_counter'] == false

        hourCounterBlock = $(event.target).closest('.nested-product-parameter').find('.tool-nested-readings')

        return if hourCounterBlock.hasClass('visible')

        hourCounterBlock.removeClass('hidden')
        hourCounterBlock.addClass('visible')

        hourCounterLinks = hourCounterBlock.find('.links')
        hourCounterBlock.find('.add-reading').trigger('click') if hourCounterLinks.is(':visible')

  $(document).on "selector:change", 'input[data-selector-id="intervention_doer_product_id"], input[data-selector-id="intervention_tool_product_id"]', (event) ->
    element = $(event.target)
    blockElement = element.closest('.nested-fields')
    participation = blockElement.find('.intervention-participation')
    hasInterventionParticipationBlock = blockElement.find('.has-intervention-participations')

    if participation.length > 0
      newProductId = element.closest('.selector').find('.selector-value').val()
      jsonParticipation = JSON.parse(participation.val())
      jsonParticipation.product_id = newProductId
      participation.val(JSON.stringify((jsonParticipation)))
      participation.attr('data-product-id', newProductId)

    if hasInterventionParticipationBlock.length == 0
      if participation.length > 0
        pictoTimer = $('<div class="has-intervention-participations picto picto-timer"></div>')
      else
        pictoTimer = $('<div class="has-intervention-participations picto picto-timer-off"></div>')

      $(blockElement).append(pictoTimer)


  $(document).on "selector:change", 'input[data-generate-items]', ->
    $(this).each ->
      E.interventions.generateItemsArrayFromId($(this))

  $(document).on "keyup change", 'input.input-quantity', ->
    $(this).each ->
      E.interventions.updateTotalAmount($(this))

  $(document).on "selector:change change", 'input.reception-supplier', ->
    $(this).each ->
      E.interventions.isPurchaseOrderSelectorEnabled($(this))

  $(document).behave "load", ".reception-supplier", ->
    supplierLabel = $($(this).parents('.nested-receptions').find('.control-label')[0])
    supplierLabel.addClass('required')
    supplierLabel.prepend("<abbr title='Obligatoire'>*</abbr>")

  $(document).on 'change', '.nested-parameters .nested-cultivation .land-parcel-plant-selector', (event) ->
    nestedCultivationBlock = $(event.target).closest('.nested-cultivation')
    unrollElement = $(nestedCultivationBlock).find('.intervention_targets_product .selector-search')
    unrollValueElement = $(nestedCultivationBlock).find('.intervention_targets_product .selector-value')

    if unrollValueElement.val() != ""
      unrollValueElement.val('')

    harvestInProgressError = $(nestedCultivationBlock).find('.harvest-in-progress-error')
    $(harvestInProgressError).remove() if $(harvestInProgressError).length > 0

    plantLandParcelSelector = new E.PlantLandParcelSelector()
    plantLandParcelSelector.changeUnrollUrl(event, unrollElement)


  $(document).on 'selector:change', '.nested-parameters .nested-cultivation .intervention_targets_product .selector-search', (event) ->
    landParcelPlantSelectorElement = $(event.target).closest('.nested-cultivation').find('.land-parcel-plant-selector')
    productId = $(event.target).closest('.selector').find('.selector-value').val()

    nestedCultivationBlock = $(event.target).closest('.nested-cultivation')
    harvestInProgressError = $(nestedCultivationBlock).find('.harvest-in-progress-error')
    $(harvestInProgressError).remove() if $(harvestInProgressError).length > 0

    E.interventionForm.checkPlantLandParcelSelector(productId, landParcelPlantSelectorElement)
    E.interventionForm.checkHarvestInProgress(event, productId, landParcelPlantSelectorElement)


  $(document).on 'keyup change dp.change', '.nested-fields.working-period input[data-intervention-updater]', (event) ->
    nestedProductParameterBlock = $('.nested-product-parameter.nested-cultivation')
    nestedProductParameterBlock = $('.nested-product-parameter.nested-plant') if $(nestedProductParameterBlock).length == 0
    nestedProductParameterBlock = $('.nested-product-parameter.nested-land_parcel') if $(nestedProductParameterBlock).length == 0

    productId = $(nestedProductParameterBlock).find('.selector .selector-value').val()

    return if productId == ""

    landParcelPlantSelectorElement = $(nestedProductParameterBlock).find('.nested-product_parameter .land-parcel-plant-selector')

    unrollBlock = $(nestedProductParameterBlock).find('.intervention_targets_product .controls')
    harvestInProgressError = $(unrollBlock).find('.harvest-in-progress-error')

    $(harvestInProgressError).remove() if $(harvestInProgressError).length > 0

    E.interventionForm.checkHarvestInProgress(event, productId, landParcelPlantSelectorElement, nestedProductParameterBlock)


  $(document).on 'selector:change', '.nested-parameters .nested-plant .intervention_targets_product .selector-search', (event, _selectedElement, wasInitializing) ->
    landParcelPlantSelectorElement = $(event.target).closest('.nested-product_parameter').find('.land-parcel-plant-selector')
    productId = $(event.target).closest('.selector').find('.selector-value').val()

    nestedCultivationBlock = $(event.target).closest('.nested-product_parameter')
    harvestInProgressError = $(nestedCultivationBlock).find('.harvest-in-progress-error')
    $(harvestInProgressError).remove() if $(harvestInProgressError).length > 0

    E.interventionForm.checkPlantLandParcelSelector(productId, landParcelPlantSelectorElement)
    E.interventionForm.checkHarvestInProgress(event, productId, landParcelPlantSelectorElement)

  $(document).on 'selector:change', "[data-selector-id=intervention_target_product_id]", (event, _selectedElement, wasInitializing) ->
    if wasInitializing
      return

    productId = $(this).next().val()
    $workingZoneAreaInput = $(this).closest('.nested-targets').find("[class$='targets_working_zone_area'] input")
    if $workingZoneAreaInput.length == 0
      return

    E.interventionForm.setWorkingZoneArea(productId, $workingZoneAreaInput)

  $(document).on 'change', '#compare-planned-and-realised', (event) ->
    $.ajax
      url: '/backend/preferences/compare_planned_and_realised'
      type: 'PATCH'
      data: { value: event.target.checked }
      success: (data) =>
        window.location.reload(true)

  $(document).on 'click', '.calendar-img', (event) ->
    return if $(event.target).parents('.task-data').attr('class').includes('no-request')
    intervention_id = $(event.target).parents('.task').data('intervention').id
    $.ajax
      url: '/backend/interventions/compare_realised_with_planned'
      data: { intervention_id: intervention_id }
      dataType: 'script'
      success: (data) =>

  $(document).on 'shown.bs.modal', '#compare-planned-with-realised', (event) ->
    $('.details').each ->
      product_id = $(this).data('productId')
      type = $(this).data('type')
      same_elements = $('.details[data-product-id=' + product_id + '][data-type=' + type + ']')
      if same_elements.length == 1
        $(this).find('h4').addClass("warning")
        return true

      planned_elements = $('.planned .details[data-product-id=' + product_id + '][data-type=' + type + ']')
      realised_elements = $('.realised .details[data-product-id=' + product_id + '][data-type=' + type + ']')
      planned_duration_sum = 0
      realised_duration_sum = 0
      data_selector = if type == 'InterventionInput' then 'quantity-population' else 'duration'
      planned_elements.each ->
        planned_quantity = $(this).data(data_selector)
        planned_quantity = parseFloat(planned_quantity)
        planned_duration_sum += planned_quantity
      realised_elements.each ->
        realised_quantity = $(this).data(data_selector)
        realised_quantity = parseFloat(realised_quantity)
        realised_duration_sum += realised_quantity

      min_interval_error = planned_duration_sum / PLANNED_REALISED_ACCEPTED_GAP[_.snakeCase(type)]
      max_interval_error = planned_duration_sum * PLANNED_REALISED_ACCEPTED_GAP[_.snakeCase(type)]
      if min_interval_error >= realised_duration_sum || max_interval_error <= realised_duration_sum
        $('.details[data-product-id=' + product_id + '][data-type=' + type + ']').find('.quantity').addClass("warning")

  E.interventionForm =
    displayCost: (target, quantity, unitName) ->

      quantity = $(target).closest('.nested-fields').find('input[data-intervention-handler="quantity"]').val()
      productId = $(target).closest('.nested-product-parameter').find(".selector .selector-value").val()

      intervention = {}
      intervention['quantity'] = quantity
      intervention['intervention_id'] = $('input[name="intervention_id"]').val()
      intervention['product_id'] = productId
      intervention['existing_participation'] = $('.intervention-participation[data-product-id="' + productId + '"]').val()
      intervention['intervention_started_at'] = $('#intervention_working_periods_attributes_0_started_at').val()
      intervention['intervention_stopped_at'] = $('#intervention_working_periods_attributes_0_stopped_at').val()

      if unitName
        intervention['unit_name'] = unitName

      return if Object.values(intervention).every( (val) -> val == undefined)

      $.ajax
        url: "/backend/interventions/costs/parameter_cost",
        data: { intervention: intervention }
        success: (data, status, request) ->
          if !data.human_amount.nature || data.human_amount.nature != "failed"
            nestedProductParameter = $(target).closest('.nested-product-parameter')

            if $(nestedProductParameter).find('.product-parameter-cost').length > 0
              $(nestedProductParameter).find('.product-parameter-cost-value').text(data.human_amount)
            else
              parameterCostBlock = $('<div class="product-parameter-cost help-block"></div>')
              parameterCostBlock.append('<span class="product-parameter-cost-label">Coût : </span>')
              parameterCostBlock.append('<span class="product-parameter-cost-value">' + data.human_amount + '</span>')

              $(nestedProductParameter).find('.intervention_inputs_quantity').append(parameterCostBlock)

    checkPlantLandParcelSelector: (productId, landParcelPlantSelectorElement) ->
      $.ajax
        url: "/backend/products/search_products/#{ productId }/datas",
        success: (data, status, request) ->
          if data.type == 'LandParcel'
            landParcelPlantSelectorElement.find('.land-parcel-radio-button').prop('checked', true)
          else
            landParcelPlantSelectorElement.find('.plant-radio-button').prop('checked', true)

    checkHarvestInProgress: (event, productId, landParcelPlantSelectorElement, nestedCultivationBlock = null) ->
      interventionNature = $('.intervention_nature input[type="hidden"]').val()

      return if $('#is_harvesting').val() == "true" ||
                  landParcelPlantSelectorElement.find('.land-parcel-radio-button').is(':checked') ||
                  interventionNature == "request"

      interventionStartedAt = $('.intervention-started-at').val()

      $.ajax
        url: "/backend/products/interventions/#{ productId }/has_harvesting",
        data: { intervention_started_at: interventionStartedAt }
        success: (data, status, request) ->
          nestedCultivationBlock ||= $(event.target).closest('.nested-product-parameter')

          unrollBlock = $(nestedCultivationBlock).find('.intervention_targets_product .controls')
          harvestInProgressError = $(unrollBlock).find('.harvest-in-progress-error')

          if $(harvestInProgressError).length > 0
            $(harvestInProgressError).remove()

          if data.has_harvesting
           unrollElement = $(nestedCultivationBlock).find('.intervention_targets_product .selector-search')

           error = $("<span class='help-inline harvest-in-progress-error'>#{ unrollElement.attr('data-harvest-in-progress-error-message') }</span>")
           $(unrollBlock).append(error)

    setupStoppedAtInputBehaviour: ->
      startedAtInput = document.querySelector("#intervention_working_periods_attributes_0_started_at")
      return unless startedAtInput

      fp = startedAtInput._flatpickr
      hiddenInput = $('#intervention_working_periods_attributes_0_stopped_at')
      autoUpdateStoppedAt = ''
      fp.set 'onOpen', (selectedDates) ->
        oldDate = moment(selectedDates[0])
        stopDate = moment(hiddenInput.val())
        autoUpdateStoppedAt = stopDate.diff(oldDate, 'seconds') == 3600
      fp.set 'onValueUpdate', (selectedDates) ->
        if autoUpdateStoppedAt
          newDate = moment(selectedDates[0])
          displayedInput = hiddenInput.next('.flatpickr-input')
          hiddenInput.val(moment(newDate).add(1, 'hours').format('Y-MM-DD H:mm'))
          displayedInput.val(moment(newDate).add(1, 'hours').format('DD-MM-Y H:mm'))
        started_at = $('#intervention_working_periods_attributes_0_started_at').val()
        $(this).each ->
          E.interventions.updateAvailabilityInstant(started_at)

    setWorkingZoneArea: (productId, $workingZoneAreaInput) ->
      $.ajax
        url: "/backend/products/#{productId}.json",
        success: (data, status, request) ->
          workingZoneAreaValue = data.netSurfaceAreaInHectare
          return unless workingZoneAreaValue

          $workingZoneAreaInput.val(workingZoneAreaValue).trigger('input')



  $(document).ready ->

    # E.interventions.hideKujakuFilters($('.view-toolbar a[data-janus-href="cobbles"]').hasClass('active'))

    if $('.new_intervention, .edit_intervention').length > 0
      E.interventions.showInterventionParticipationsModal()


    if $('.edit_intervention').length > 0
      $('.nested-association.nested-inputs .nested-product-parameter').each((index, parameter) ->
        productParameterCostBlock = $(parameter).find('.product-parameter-cost')

        if productParameterCostBlock.length > 0
          target = $(parameter).find('.intervention_inputs_quantity')
          $(productParameterCostBlock).appendTo(target)
      )

    if $('.taskboard').length > 0 && $('.kujaku').length > 0

      taskboard = new InterventionsTaskboard
      taskboard.initTaskboard()

      encodedUrlParams = $('.kujaku').find('form').serialize()
      urlParams = decodeURIComponent(encodedUrlParams).split("&")
      params = urlParams.reduce((map, obj) ->
        param = obj.split("=")
        map[param[0]] = param[1]
        return map
      , {})

      E.interventions.addLazyLoading(taskboard, params)


  class InterventionsTaskboard

    constructor: ->
      @taskboard = new ekylibre.taskboard('#interventions', true)
      @taskboardModal = new ekylibre.modal('#taskboard-modal')

    initTaskboard: ->
      this.addHeaderActionsEvent()
      this.addEditIconClickEvent()
      this.addDeleteIconClickEvent()
      this.addTaskClickEvent()

    getTaskboard: ->
      return @taskboard

    getTaskboardModal: ->
      return @taskboardModal

    addHeaderActionsEvent: ->

      instance = this

      @taskboard.addSelectTaskEvent((event) ->

          selectedField = $(event.target)
          columnIndex = instance.getTaskboard().getColumnIndex(selectedField)
          header = instance.getTaskboard().getHeaderByIndex(columnIndex)
          checkedFieldsCount = instance.getTaskboard().getCheckedSelectFieldsCount(selectedField)

          if (checkedFieldsCount == 0)

            instance.getTaskboard().hiddenHeaderIcons(header)
          else
            instance.getTaskboard().displayHeaderIcons(header)
      )

    addEditIconClickEvent: ->

      instance = this

      @taskboard.getHeaderActions().find('.edit-tasks').on('click', (event) ->

        interventionsIds = instance._getSelectedInterventionsIds(event.target)
        $.ajax
          url: "/backend/interventions/modal",
          data: {interventions_ids: interventionsIds}
          success: (data, status, request) ->

            instance._displayModalWithContent(data)
      )


    addDeleteIconClickEvent: ->

      instance = this

      $('.delete-tasks').on('click', (event) ->

        ekylibre.stopEvent(event)

        confirmMessage = $(event.target).attr('data-confirm')
        answer = confirm(confirmMessage);

        if !answer
          return

        displayDeleteModal = true
        columnSelector = event.target
        interventionsIds = instance._getSelectedInterventionsIds(columnSelector)

        tasksWithAttribute = instance.getTaskboard().getColumnTasksFilledDataAttribute(columnSelector, 'data-request-intervention-id')

        if (!tasksWithAttribute || tasksWithAttribute.length == 0)
          displayDeleteModal = false
        else
          tasksWithAttribute.each((index, taskWithAttribute) ->

            attributeValue = $(taskWithAttribute).attr('data-request-intervention-id')
            tasksWithThisAttributeValue = instance.getTaskboard().getColumnTasksByDataAttributeValue(columnSelector, 'data-request-intervention-id', attributeValue)

            if (tasksWithThisAttributeValue && tasksWithThisAttributeValue.length > 1)
              displayDeleteModal = false
          )

        if (displayDeleteModal)
          $.ajax
            url: "/backend/interventions/modal",
            data: {modal_type: "delete", interventions_ids: interventionsIds}
            success: (data, status, request) ->

              instance._displayModalWithContent(data)
        else
          instance._removeInterventions(columnSelector, interventionsIds)

      )

    _removeInterventions: (columnSelector, interventionsIds) ->

      instance = this

      $.ajax
        method: 'POST'
        url: "/backend/interventions/change_state",
        data: {
          'intervention': {
            interventions_ids: JSON.stringify(interventionsIds),
            state: 'rejected'
          }
        }
        success: (data, status, request) ->

          interventionsIds.forEach (intervention_id) ->
            $('#interventions-list tr[id*="'+intervention_id+'"]').remove()

          selectedTasks = instance.getTaskboard().getSelectedTasksByColumnSelector(columnSelector)
          selectedTasks.remove()

          titleElement = $(columnSelector).closest('.taskboard-header').find('.title')
          columnTitle = titleElement.text()
          beginInterventionCount = columnTitle.indexOf("(") + 1
          columnInterventionCount = columnTitle.slice(beginInterventionCount, -1)
          newInterventionCount = parseInt(columnInterventionCount) - interventionsIds.length
          newColumnTitle = columnTitle.slice(0, beginInterventionCount) + newInterventionCount+")"
          titleElement.text(newColumnTitle)

          if newInterventionCount == 0
            $(columnSelector).closest('.taskboard-column').find('.tasks').remove()


    _getSelectedInterventionsIds: (columnSelector) ->

      selectedTasks = @taskboard.getSelectedTasksByColumnSelector(columnSelector)

      interventionsIds = [];
      selectedTasks.each( ->

        interventionDatas = JSON.parse($(this).attr('data-intervention'))
        interventionsIds.push(interventionDatas.id);
      );

      return interventionsIds


    addTaskClickEvent: ->

      instance = this

      @taskboard.addTaskClickEvent((event) ->

        element = $(event.target)

        if (element.is(':input[type="checkbox"]') || $(event.target).attr('class') == 'calendar-img')
          return

        task = element.closest('.task')

        intervention = JSON.parse(task.attr('data-intervention'))
        $.ajax
          url: "/backend/interventions/modal",
          data: {intervention_id: intervention.id}
          success: (data, status, request) ->

            instance._displayModalWithContent(data)
            instance.getTaskboardModal().getModal().find('.dropup a').on('click', (event) ->

              dropdown = $(this).closest('.dropup')
              dropdown.removeClass('open')

              dropdownButton = dropdown.find('.dropdown-toggle')
              dropdownButton.text(dropdownButton.attr('data-disable-with'))
              dropdownButton.attr('disabled', 'disabled')
            )
      )


    _displayModalWithContent: (data) ->

      @taskboardModal.removeModalContent()
      @taskboardModal.getModalContent().append(data)
      @taskboardModal.getModal().modal 'show'

  true

  $(document).ready ->
    #TODO: Refacto this to not be coupled so tight to URL
    if window.location.pathname.includes('/backend/interventions/')
      path = window.location.pathname
      intervention = path.substring(path.lastIndexOf('/') + 1);
      $.ajax
        url: '/backend/interventions/generate_buttons'
        data: { interventions: [intervention] }
        success: (data) =>
          unless data == null
            $('.main-toolbar').append(data)

    $(document).on 'change', '#interventions-list .list-selector', (e) =>
      e.stopImmediatePropagation();
      interventions = $.map( $(".list-data input:checked"), (n, i) ->
          n.value
      )
      $('.duplicate-intervention').remove()

      $.ajax
        url: '/backend/interventions/generate_buttons'
        data: { interventions: interventions }
        success: (data) =>
          $('.main-toolbar').append(data)

    $(document).on 'change', '.requests #check_nature', (e) =>
      e.stopImmediatePropagation();
      $(e.currentTarget).parent('.task')
      $(e.currentTarget).closest('.taskboard-column').find(".taskboard-header")
      interventions = $.map($('.requests .tasks input:checked'), (n, i) ->
        $(n).closest('.task').data().intervention.id
      )
      $('.requests .duplicate-intervention').remove()
      $.ajax
        url: '/backend/interventions/generate_buttons'
        data: { interventions: interventions, icon_btn: true }
        success: (data) =>
          unless data == null
            $('.requests .edit-tasks').after("<i class='picto picto-plus duplicate-intervention' title='#{data.translation}'></i>")
            $('.duplicate-intervention').data('interventions', interventions)


    $('#taskboard-modal').on 'show.bs.modal', (e) =>
      e.stopImmediatePropagation();
      intervention = $(e.currentTarget).find(".modal-body").data().interventionId
      $.ajax
        url: '/backend/interventions/generate_buttons'
        data: { interventions: [intervention] }
        success: (data) =>
          unless data == null
            $(e.currentTarget).find('.duplicate-intervention').remove()
            $(e.currentTarget).find('.modal-footer').append(data)


    $(document).on 'click', '.duplicate-intervention', (e) =>
      e.stopImmediatePropagation();
      interventions = $(e.currentTarget).data().interventions
      $.ajax
        url: '/backend/interventions/duplicate_interventions'
        data: { interventions: interventions }
        success: (data) =>
          if $('#taskboard-modal').length > 0
            interventionModal = new ekylibre.modal('#taskboard-modal')
            interventionModal.getModal().modal 'hide'
          else
            interventionModal = new ekylibre.modal('#create-intervention-modal')
            interventionModal.getModal().modal 'hide'
          $('#wrap').after(data)
          duplicateModal = new ekylibre.modal('#duplicate-modal')
          duplicateModal.getModal().modal 'show'

    $(document).on 'click', '#duplicate-modal #validate-duplication', (e) =>
      e.stopImmediatePropagation();
      intervention = $(e.currentTarget).data().intervention
      interventions = $(e.currentTarget).data().interventions
      duplicateModal = new ekylibre.modal('#duplicate-modal')
      date = $('#duplicate-modal #duplicate_date').val()
      form = $('.edit_intervention:visible')
      $.ajax
        type: 'post'
        url: '/backend/interventions/create_duplicate_intervention'
        data: { intervention: intervention, interventions: interventions, date: date, form: form.serialize() }
        success: (data) =>
          if data == null
            duplicateModal.getModal().modal 'hide'
            location.reload();
          else if data.errors != undefined
            $('#duplicate-modal .modal-header').append("<div class='errors'>#{data.errors}</div>")
          else
            duplicateModal.getModal().modal 'hide'
            $('#duplicate-modal').remove()
            $('#wrap').after(data)
            duplicateModal = new ekylibre.modal('#duplicate-modal')
            duplicateModal.getModal().modal 'show'

    $(document).on 'change intervention-field:value-updated', '.nested-fields.working-period input', ->
      updateHarvestDelayWarnings()

    $(document).on 'selector:change', ".nested-targets .intervention_targets_product", ->
      updateHarvestDelayWarnings()

    $(document).on 'cocoon:after-remove', '.nested-working_periods', ->
      updateHarvestDelayWarnings()

  queryDelayWarningsForPeriod = ($periodElement, $parcelSelectors) =>
    console.log('retrieve succeeded')
    $dateInput = $periodElement.find("input[id*='started_at']")[0]
    $dateEndInput = $periodElement.find("input[id*='stopped_at']")[0]
    date = moment($dateInput.value).toISOString()
    dateEnd = moment($dateEndInput.value).toISOString()
    parcels = $parcelSelectors.get().map((e) => $(e).find('.selector input:first-child').get(0) ).map((e) => $(e).selector('value')).filter((e) => e != null)

    return Promise.resolve([]) if parcels.length == 0

    params = {
      date: date,
      date_end: dateEnd,
      targets: parcels
    }

    intervention_id = $('#intervention_id').val()
    if intervention_id != ""
      params['ignore_intervention'] = intervention_id

    p = E.ajax.json(url: "/backend/interventions/validate_reentry_delay?#{$.param(params)}")
      .then(filter_for('reentry'))

    if $('#updater').data('procedure-computing') == "harvesting"
      p2 = E.ajax.json(url: "/backend/interventions/validate_harvest_delay?#{$.param(params)}")
        .then(filter_for('harvest'))

      p = Promise.all([p, p2]).then (array) =>
        reentry = array[0]
        harvest = array[1]
        harvest.map (t) =>
          if (t.possible)
            reentry.filter((el) => el.id == t.id)[0]
          else
            t
    p

  updateHarvestDelayWarnings = _.debounce ->
    $parcelSelectors = $('.nested-targets .intervention_targets_product')
    promises = $('.nested-fields.working-period').toArray().map (e) =>
      queryDelayWarningsForPeriod($(e), $parcelSelectors)

    Promise.all(promises).then (values) =>
      removeHarvestWarnings($parcelSelectors)
      values.forEach (problems) =>
        harvestImpossible = problems.filter((t) => t.possible == false)
        displayWarningMessages(harvestImpossible)


  filter_for = (action) =>
    (data) =>
      data.targets.map (t) =>
        t['action'] = action
        t

  removeHarvestWarnings = ($parcelSelectors) =>
    $parcelSelectors.find('.controls .harvest-warning').remove()

  displayWarningMessages = (warnings) =>
    for data in warnings
      date = moment(data.date).format('DD-MM-YYYY HH:mm')
      harvestWarning = $(".selector-value[value='#{data.id}']").closest('.controls')
      message = I18n.translate("front-end.intervention.nature.#{data.action}")
      harvestWarning.append("<div class='harvest-warning'><i class='picto picto-clear'></i> <span>#{message} #{date}</span></div>")
      if $(".harvest-warning").length == 1 && data.action == "reentry" && moment.duration(data.period_duration).asHours() == 8
        addTwoHours = I18n.translate("front-end.intervention.nature.add_two_hours")
        $(".harvest-warning").append("<span>#{addTwoHours}</span>")

  settingForm = {
    updateInsertedSettingName: ($settingField, insertedItem) ->
      builtCount = $settingField.find(".parameter-setting").length
      $nameInput = insertedItem.find('[name$="[name]"]')
      name = $nameInput.val()
      nameIndexRegex = /[0-9]*$/ #match 15 in 'Réglage nº15'
      newName = name.replace(nameIndexRegex, builtCount )
      $nameInput.val(newName)
  }

  $(document).on('cocoon:after-insert', '#parameter-settings', (e, insertedItem ) ->
    settingForm.updateInsertedSettingName($(this), insertedItem)
  )

  productService = new E.ProductService()

  sprayerForm = {
    selectors: {
      toolInput: '.intervention_tools_product [data-selector]'
      editSprayerLink: '#edit-product'
      configureProductDiv: '#configure-product'
      reloadSprayerLink: '#configure-product i'
    },

    handleConfigureProductDiv: ($nestedField) ->
     $configureProductDiv = $nestedField.find(sprayerForm.selectors.configureProductDiv)
     $configureProductDiv.css('display', 'inline-block')

    handleLinkToProductEdit: ($nestedField, id) ->
      $editSprayerLink = $nestedField.find(sprayerForm.selectors.editSprayerLink)
      $editSprayerLink.attr("href", $editSprayerLink.attr("href").replace(/[0-9]*(?=\/edit)/, id))

    setReadings: ($nestedField, readings) ->
      regex = /\[([^\]\[]+)\]$/
      for _i, reading of readings
        $readingDiv = $nestedField.find(".#{reading.indicator_name}")
        $readingDiv.find('input').each( (_index) ->
          match = regex.exec(this.name)
          name = match[1]
          if this.disabled == true
            this.setAttribute('value', reading['measure_value_unit_symbol'])
          else
            this.setAttribute('value', reading[name])
            # this.classList.add('disabled')
        )

    updateReadingInputs: ($selector, id) ->
      productService.get(id).then( (product) ->
        sprayerForm.setReadings($selector, product.readings)
      )

    onSelectorChange: ($selector, id) ->
      $nestedField = $selector.parents(".nested-fields")
      @handleLinkToProductEdit($nestedField, id)
      @handleConfigureProductDiv($nestedField)
      @updateReadingInputs($nestedField,id)
  }

  $(document).on 'selector:change', sprayerForm.selectors.toolInput, (_event, _selectedElement, was_initializing) ->
    if was_initializing
      return
    id = $(@).next().val()
    sprayerForm.onSelectorChange($(@), id)

  $(document).on 'click', sprayerForm.selectors.reloadSprayerLink, (event) ->
    $nestedField = $(this).parents(".nested-fields")
    productId = $nestedField.find(sprayerForm.selectors.toolInput).next().val()
    sprayerForm.updateReadingInputs($nestedField,productId)
  
  refreshQuantityWithDelay =  ->
    $("*[data-intervention-updater$='quantity_value']").each (i) ->
      that = this
      debounceTime = 1000 * (1 + i * 2) # Refresh won't be performed if executed at the same time, each quantity refresh will be performed every seconds
      _.debounce( ->
        E.interventions.refresh $(that)
      , debounceTime)()

  refreshQuantityWhenTargetChange = ->
    $(document).on 'mapchange', "[data-intervention-updater$='working_zone']",
      refreshQuantityWithDelay

    $(document).on 'input', "[data-intervention-updater$='working_zone_area_value']",
      refreshQuantityWithDelay

  # Hack: we need to recompute quantity population when target change
  refreshQuantityWhenTargetChange()


) ekylibre, jQuery
