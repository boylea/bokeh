_ = require "underscore"
$ = require "jquery"
Model = require "../../model"
p = require "../../core/properties"
{GE, EQ, Strength, Variable}  = require "../../core/layout/solver"

build_views = require "../../common/build_views"

BokehView = require "../../core/bokeh_view"
{logger} = require "../../core/logging"


class LayoutDOMView extends BokehView

  initialize: (options) ->
    super(options)
    # Provides a hook so document can measure
    @$el.attr("id", "modelid_#{@model.id}")
    @$el.addClass("bk-layout-#{@model.responsive}")

    children = @model.get_layoutable_children()
    @child_views = {}
    build_views(@child_views, children)

    for child in children
      # Look-up the child_view in @child_views and then append
      # We can't just read from @child_views because then we
      # don't get guaranteed ordering. Which is a problem in
      # non-box layouts.
      child_view = @child_views[child.id]
      @$el.append(child_view.$el)

    @bind_bokeh_events()

    if @model._is_root is true
      resize = () -> $(window).trigger('resize')
      _.delay(resize, 50)
      _.delay(resize, 100)
      _.delay(resize, 200)

  bind_bokeh_events: () ->
    @listenTo(@model, 'change', @render)
    @listenTo(@model.document.solver(), 'resize', @render)

  render: () ->
    #logger.debug("#{@model} _dom_left: #{@model._dom_left._value}, _dom_top: #{@model._dom_top._value}")
    #logger.debug("#{@model} _top: #{@model._top._value}, _right: #{@model._right._value}, _bottom: #{@model._bottom._value}, _left: #{@model._left._value}")
    #logger.debug("#{@model} _width: #{@model._width._value}, _height: #{@model._height._value}")
    #logger.debug("#{@model} _width_minus_right: #{@model._width_minus_right._value}, _height_minus_bottom: #{@model._height_minus_bottom._value}")

    s = @model.document.solver()

    if @model.responsive is 'fixed'
      # If the width or height is unset:
      # - compute it from children
      # - but then save for future use
      # (for some reason widget boxes keep shrinking if you keep computing
      # but this is more efficient and appropriate for fixed anyway).
      if @model.width?
        width = @model.width
      else
        width = @get_width()
        @model.width = width
      if @model.height?
        height = @model.height
      else
        height = @get_height()
        @model.height = height

      s.suggest_value(@model._width, width)
      s.suggest_value(@model._height, height)
      s.update_variables()
      @$el.css({
        width: width
        height: height
      })

    if @model.responsive is 'width_ar'
      height = @get_height()

      s.suggest_value(@model._height, height)
      s.update_variables()
      @$el.css({
        width: @model._width._value
        height: @model._height._value
      })

    if @model.responsive is 'height_ar'
      width = @get_width()

      s.suggest_value(@model._width, width)
      s.update_variables()
      @$el.css({
        width: @model._width._value
        height: @model._height._value
      })

    if @model.responsive is 'box'
      @$el.css({
        position: 'absolute'
        left: @model._dom_left._value
        top: @model._dom_top._value
        width: @model._width._value
        height: @model._height._value
      })

  get_height: () ->
    # Subclasses should implement this to explain
    # what their height should be in responsive mode.
    return null

  get_width: () ->
    # Subclasses should implement this to explain
    # what their width should be in responsive mode.
    return null



class LayoutDOM extends Model
  type: "LayoutDOM"

  constructor: (attrs, options) ->
    super(attrs, options)
    @_width = new Variable("_width #{@id}")
    @_height = new Variable("_height #{@id}")
    # These are the COORDINATES of the four plot sides
    @_left = new Variable("_left #{@id}")
    @_right = new Variable("_right #{@id}")
    @_top = new Variable("_top #{@id}")
    @_bottom = new Variable("_bottom #{@id}")
    # This is the dom position
    @_dom_top = new Variable("_dom_top #{@id}")
    @_dom_left = new Variable("_dom_left #{@id}")
    # This is the distance from the side of the right and bottom,
    @_width_minus_right = new Variable("_width_minus_right #{@id}")
    @_height_minus_bottom = new Variable("_height_minus_bottom #{@id}")
    # Whitespace variables
    @_whitespace_top = new Variable()
    @_whitespace_bottom = new Variable()
    @_whitespace_left = new Variable()
    @_whitespace_right = new Variable()

  get_constraints: () ->
    constraints = []

    # Make sure things dont squeeze out of their bounding box
    constraints.push(GE(@_dom_left))
    constraints.push(GE(@_dom_top))

    # Plot has to be inside the width/height
    constraints.push(GE(@_left))
    constraints.push(GE(@_width, [-1, @_right]))
    constraints.push(GE(@_top))
    constraints.push(GE(@_height, [-1, @_bottom]))

    ## Declare computed constraints
    constraints.push(EQ(@_width_minus_right, [-1, @_width], @_right))
    constraints.push(EQ(@_height_minus_bottom, [-1, @_height], @_bottom))

    return constraints

  get_layoutable_children: () ->
    []

  get_edit_variables: () ->
    edit_variables = []
    if @responsive is 'fixed'
      edit_variables.push({edit_variable: @_height, strength: Strength.strong})
      edit_variables.push({edit_variable: @_width, strength: Strength.strong})
    if @responsive is 'width_ar'
      edit_variables.push({edit_variable: @_height, strength: Strength.strong})
    if @responsive is 'height_ar'
      edit_variables.push({edit_variable: @_width, strength: Strength.strong})
    return edit_variables

  get_constrained_variables: () ->
    # THE FOLLOWING ARE OPTIONAL VARS THAT
    # YOU COULD ADD INTO SUBCLASSES
    #
    #  # When this widget is on the edge of a box visually,
    #  # align these variables down that edge. Right/bottom
    #  # are an inset from the edge.
    #  'on-edge-align-top'    : @_top
    #  'on-edge-align-bottom' : @_height_minus_bottom
    #  'on-edge-align-left'   : @_left
    #  'on-edge-align-right'  : @_width_minus_right
    #  # When this widget is in a box cell with the same "arity
    #  # path" as a widget in another cell, align these variables
    #  # between the two box cells. Right/bottom are an inset from
    #  # the edge.
    #  'box-cell-align-top'   : @_top
    #  'box-cell-align-bottom': @_height_minus_bottom
    #  'box-cell-align-left'  : @_left
    #  'box-cell-align-right' : @_width_minus_right
    #  # When this widget is in a box, make these the same distance
    #  # apart in every widget. Right/bottom are inset from the edge.
    #  'box-equal-size-top'   : @_top
    #  'box-equal-size-bottom': @_height_minus_bottom
    #  'box-equal-size-left'  : @_left
    #  'box-equal-size-right' : @_width_minus_right

    constrained_variables = {
      'origin-x': @_dom_left
      'origin-y': @_dom_top
      'whitespace-top' : @_whitespace_top
      'whitespace-bottom' : @_whitespace_bottom
      'whitespace-left' : @_whitespace_left
      'whitespace-right' : @_whitespace_right
    }
    if @responsive is 'box'
      constrained_variables = _.extend(constrained_variables, {
        'width': @_width
        'height': @_height
      })
    if @responsive is 'width_ar'
      constrained_variables = _.extend(constrained_variables, {
        'width': @_width
      })
    if @responsive is 'height_ar'
      constrained_variables = _.extend(constrained_variables, {
        'height': @_height
      })
    return constrained_variables

  @define {
      height:   [ p.Number, null ]
      width:    [ p.Number, null ]
      disabled: [ p.Bool, false ]
      responsive: [ p.Responsive, null ]
    }

  @internal {
      layoutable: [ p.Bool, true ]
  }

module.exports =
  Model: LayoutDOM
  View: LayoutDOMView
