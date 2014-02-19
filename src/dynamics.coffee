# Browser Support
# IE9+ because of window.getComputedStyle

# Private Classes
## Dynamics
class Dynamic
  @properties: {}

  constructor: (@options = {}) ->

  init: =>
    @t = 0

  next: (step) =>
    @t = 1 if @t > 1
    r = @at(@t)
    @t += step
    r

  at: (t) =>
    [t, t]

class Linear extends Dynamic
  @properties:
    duration: { min: 100, max: 4000, default: 1000 }

  init: =>
    super

  at: (t) =>
    [t, t]

class Gravity extends Dynamic
  @properties:
    bounce: { min: 0, max: 80, default: 40 }
    gravity: { min: 1, max: 4000, default: 1000 }
    expectedDuration: { editable: false }

  constructor: (@options = {}) ->
    @options.duration = @duration()
    super @options

  expectedDuration: =>
    @duration()

  duration: =>
    Math.round(1000 * 1000 / @options.gravity * @length())

  bounceValue: =>
    bounce = (@options.bounce / 100)
    bounce = Math.min(bounce, 80)
    bounce

  gravityValue: =>
    @options.gravity / 100

  length: =>
    bounce = @bounceValue()
    gravity = @gravityValue()
    b = Math.sqrt(2 / gravity)
    curve = { a: -b, b: b, H: 1 }
    if @options.initialForce
      curve.a = 0
      curve.b = curve.b * 2
    while curve.H > 0.001
      L = curve.b - curve.a
      curve = { a: curve.b, b: curve.b + L * bounce, H: curve.H * bounce * bounce }
    curve.b

  init: =>
    super
    L = @length()
    gravity = @gravityValue()
    gravity = gravity * L * L
    bounce = @bounceValue()

    b = Math.sqrt(2 / gravity)
    @curves = []
    curve = { a: -b, b: b, H: 1 }
    if @options.initialForce
      curve.a = 0
      curve.b = curve.b * 2
    @curves.push curve
    while curve.b < 1 and curve.H > 0.001
      L = curve.b - curve.a
      curve = { a: curve.b, b: curve.b + L * bounce, H: curve.H * bounce * bounce }
      @curves.push curve

  curve: (a, b, H, t) =>
    L = b - a
    t2 = (2 / L) * (t) - 1 - (a * 2 / L)
    c = t2 * t2 * H - H + 1
    c = 1 - c if @options.initialForce
    c

  at: (t) =>
    bounce = (@options.bounce / 100)
    gravity = @options.gravity

    i = 0
    curve = @curves[i]
    while(!(t >= curve.a and t <= curve.b))
      i += 1
      curve = @curves[i]
      break unless curve

    if !curve
      if @options.initialForce
        v = 0
      else
        v = 1
    else
      v = @curve(curve.a, curve.b, curve.H, t)

    [t, v]

class GravityWithForce extends Gravity
  returnsToSelf: true

  constructor: (@options = {}) ->
    @options.initialForce = true
    super @options

class Spring extends Dynamic
  @properties:
    frequency: { min: 0, max: 100, default: 15 }
    friction: { min: 1, max: 1000, default: 100 }
    anticipationStrength: { min: 0, max: 1000, default: 115 }
    anticipationSize: { min: 0, max: 99, default: 10 }
    duration: { min: 100, max: 4000, default: 1000 }

  at: (t) =>
    frequency = Math.max(1, @options.frequency)
    friction = Math.pow(20, (@options.friction / 100))
    s = @options.anticipationSize / 100
    decal = Math.max(0, s)

    frictionT = (t / (1 - s)) - (s / (1 - s))

    if t < s
      # In case of anticipation
      A = (t) =>
        M = 0.8

        x0 = (s / (1 - s))
        x1 = 0

        b = (x0 - (M * x1)) / (x0 - x1)
        a = (M - b) / x0

        (a * t * @options.anticipationStrength / 100) + b

      yS = (s / (1 - s)) - (s / (1 - s))
      y0 = (0 / (1 - s)) - (s / (1 - s))
      b = Math.acos(1 / A(yS))
      a = (Math.acos(1 / A(y0)) - b) / (frequency * (-s))
    else
      # Normal curve
      A = (t) =>
        Math.pow(friction / 10,-t) * (1 - t)

      b = 0
      a = 1

    At = A(frictionT)

    angle = frequency * (t - s) * a + b
    v = 1 - (At * Math.cos(angle))
    [t, v, At, frictionT, angle]

class SelfSpring extends Dynamic
  @properties:
    frequency: { min: 0, max: 100, default: 15 }
    friction: { min: 1, max: 1000, default: 100 }
    duration: { min: 100, max: 4000, default: 1000 }

  returnsToSelf: true

  at: (t) =>
    frequency = Math.max(1, @options.frequency)
    friction = Math.pow(20, (@options.friction / 100))

    # Normal curve
    A = (t) =>
      1 - Math.pow(friction / 10,-t) * (1 - t)

    At = A(t)
    At2 = A(1-t)

    Ax = (Math.cos(t * 2 * 3.14 - 3.14) / 2) + 0.5
    Ax = Math.pow(Ax, @options.friction / 100)

    angle = frequency * t
    # v = 1 - (At * Math.cos(angle))
    v = Math.cos(angle) * Ax
    [t, v, Ax, -Ax]

class Bezier extends Dynamic
  @properties:
    points: { type: 'points', default: [ {
        x: 0,
        y: 0,
        controlPoints: [{
          x: 0.2,
          y: 0
        }]
      },
      {
        x: 0.3,
        y: 1.2,
        controlPoints: [{
          x: 0.2,
          y: 1.2
        },{
          x: 0.4,
          y: 1.2
        }]
      },
      {
        x: 0.7,
        y: 0.8,
        controlPoints: [{
          x: 0.6,
          y: 0.8
        },{
          x: 0.8,
          y: 0.8
        }]
      },
      {
        x: 1,
        y: 1,
        controlPoints: [{
          x: 0.9,
          y: 1
        }]
      }] }
    duration: { min: 100, max: 4000, default: 1000 }

  constructor: (@options = {}) ->
    @returnsToSelf = @options.points[@options.points.length - 1].y == 0
    super @options

  B_: (t, p0, p1, p2, p3) =>
    (Math.pow(1 - t, 3) * p0) + (3 * Math.pow(1 - t, 2) * t * p1) + (3 * (1 - t) * Math.pow(t, 2) * p2) + Math.pow(t, 3) * p3

  B: (t, p0, p1, p2, p3) =>
    {
      x: @B_(t, p0.x, p1.x, p2.x, p3.x),
      y: @B_(t, p0.y, p1.y, p2.y, p3.y)
    }

  yForX: (xTarget, Bs) =>
    # Find the right Bezier curve first
    B = null
    for aB in Bs
      if xTarget >= aB(0).x and xTarget <= aB(1).x
        B = aB
      break if B != null

    unless B
      if @returnsToSelf
        return 0
      else
        return 1

    # Find the percent with dichotomy
    xTolerance = 0.0001
    lower = 0
    upper = 1
    percent = (upper + lower) / 2

    x = B(percent).x
    i = 0

    while Math.abs(xTarget - x) > xTolerance and i < 100
      if xTarget > x
        lower = percent
      else
        upper = percent

      percent = (upper + lower) / 2
      x = B(percent).x
      i += 1

    # Returns y at this specific percent
    return B(percent).y;

  at: (t) =>
    x = t
    points = @options.points || Bezier.properties.points.default
    Bs = []
    for i of points
      k = parseInt(i)
      break if k >= points.length - 1
      ((pointA, pointB) =>
        B = (t) =>
          @B(t, pointA, pointA.controlPoints[pointA.controlPoints.length - 1], pointB.controlPoints[0], pointB)
        Bs.push(B)
      )(points[k], points[k + 1])
    y = @yForX(x, Bs)
    [x, y]

## Helpers
class BrowserSupport
  @transform: ->
    @withPrefix("transform")

  @keyframes: ->
    return "-webkit-keyframes" if document.body.style.webkitAnimation != undefined
    return "-moz-keyframes" if document.body.style.mozAnimation != undefined
    "keyframes"

  @withPrefix: (property) ->
    prefix = @prefixFor(property)
    return "#{prefix}#{property.substring(0, 1).toUpperCase() + property.substring(1)}" if prefix == 'Moz'
    return "-#{prefix.toLowerCase()}-#{property}" if prefix != ''
    property

  @prefixFor: (property) ->
    propArray = property.split('-')
    propertyName = ""
    for prop in propArray
      propertyName += prop.substring(0, 1).toUpperCase() + prop.substring(1)
    for prefix in [ "Webkit", "Moz" ]
      k = prefix + propertyName
      if document.body.style[k] != undefined
        return prefix
    ''

# Public Classes
class Animation
  @index: 0

  constructor: (@el, @to, options = {}) ->
    redraw = @el.offsetHeight # Hack to redraw the element
    @frames = @parseFrames({
      0: @getFirstFrame(@to),
      100: @to
    })
    @setOptions(options)
    if @options.debug and Dynamics.InteractivePanel
      Dynamics.InteractivePanel.addAnimation(@)

  setOptions: (options = {}) =>
    optionsChanged = @options?.optionsChanged

    @options = options
    @options.duration ||= 1000
    @options.complete ||= null
    @options.type ||= Linear
    @returnsToSelf = false || @dynamic().returnsToSelf
    @_dynamic = null

    optionsChanged?()

  dynamic: =>
    @_dynamic ||= new @options.type(this.options)
    @_dynamic

  convertTransformToMatrix: (transform, callback) =>
    matrixEl = document.createElement('div')
    matrixEl.style[BrowserSupport.transform()] = transform
    document.body.appendChild(matrixEl)
    style = window.getComputedStyle(matrixEl, null)
    result = style.transform || style[BrowserSupport.transform()]
    document.body.removeChild(matrixEl)
    result

  convertToMatrix3d: (transform) =>
    unless /matrix/.test transform
      transform = 'matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)'
    else
      # format: matrix(a, c, b, d, tx, ty)
      match = transform.match /matrix\(([-0-9\.]*), ([-0-9\.]*), ([-0-9\.]*), ([-0-9\.]*), ([-0-9\.]*), ([-0-9\.]*)\)/
      if match
        a = parseFloat(match[1])
        b = parseFloat(match[2])
        c = parseFloat(match[3])
        d = parseFloat(match[4])
        tx = parseFloat(match[5])
        ty = parseFloat(match[6])
        transform = "matrix3d(#{a}, #{b}, 0, 0, #{c}, #{d}, 0, 0, 0, 0, 1, 0, #{tx}, #{ty}, 0, 1)"

    # format: matrix3d(a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1)
    match = transform.match /matrix3d\(([^)]*)\)/
    elements = null
    if match
      content = match[1]
      elements = content.split(',').map(parseFloat)
    elements

  getFirstFrame: (properties) =>
    frame = {}
    style = window.getComputedStyle(@el, null)
    for k of properties
      v = @el.style[BrowserSupport.withPrefix(k)]
      v = style[BrowserSupport.withPrefix(k)] unless v
      frame[k] = v
    frame

  parseFrames: (frames) =>
    newFrames = {}
    for percent, properties of frames
      newProperties = {}
      for k, v of properties
        if k != 'transform'
          vString = v + ""
          match = vString.match /([-0-9.]*)(.*)/
          value = parseFloat(match[1])
          unit = match[2]
        else
          value = @convertToMatrix3d(@convertTransformToMatrix(v))
          unit = ''
        newProperties[k] = {
          value: value,
          unit: unit
        }
      newFrames[percent] = newProperties
    newFrames

  defaultForProperty: (property) =>
    return 1 if property in ['scaleX', 'scaleY', 'scale']
    0

  start: =>
    @ts = null
    @dynamic().init()
    requestAnimationFrame @frame

  frame: (ts) =>
    t = 0
    if @ts
      dTs = ts - @ts
      t = dTs / @options.duration
    else
      @ts = ts

    at = @dynamic().at(t)

    frame0 = @frames[0]
    frame1 = @frames[100]

    transform = ''
    properties = {}
    for k, v of frame1
      value = v.value
      unit = v.unit

      if value instanceof Array
        oldValue = frame0[k].value
        newValue = []
        for i of value
          dValue = value[i] - oldValue[i]
          newValue.push(oldValue[i] + (dValue * at[1]))
        properties['transform'] = "matrix3d(#{newValue.join(',')})"
      else
        oldValue = null
        oldValue = frame0[k].value if frame0[k]
        oldValue = @defaultForProperty(k) unless oldValue
        dValue = value - oldValue
        newValue = oldValue + (dValue * at[1])
        properties[k] = newValue

    for k, v of properties
      @el.style[BrowserSupport.withPrefix(k)] = v

    if t < 1
      requestAnimationFrame @frame
    else
      @options.complete?()

  keyframesStart: =>
    name = "anim_#{Animation.index}"
    Animation.index += 1
    keyframes = @_keyframes(name)
    style = document.createElement('style')
    style.innerHTML = keyframes
    document.head.appendChild(style)

    animation = {
      name: name,
      duration: @options.duration + 'ms',
      timingFunction: 'linear',
      fillMode: 'forwards'
    }
    for k, v of animation
      property = "animation-#{k}"
      prefix = BrowserSupport.prefixFor(property)
      propertyName = prefix + "Animation" + k.substring(0, 1).toUpperCase() + k.substring(1)
      @el.style[propertyName] = v
    @_listenAnimationEnd()

  # Private
  _listenAnimationEnd: =>
    events = [
      'animationend',
      'webkitAnimationEnd',
      'MozAnimationEnd',
      'oAnimationEnd'
    ]
    for event in events
      eventCallback = (e) =>
        return if e.target != @el
        @el.removeEventListener event, eventCallback
        @options.complete?()
      @el.addEventListener event, eventCallback

  _keyframes: (name) =>
    @dynamic().init()
    step = 0.01

    frame0 = @frames[0]
    frame1 = @frames[100]

    css = "@#{BrowserSupport.keyframes()} #{name} {\n"
    while args = @dynamic().next(step)
      [t, v] = args

      transform = ''
      properties = {}
      for k, value of frame1
        value = parseFloat(value)
        oldValue = frame0[k] || 0
        dValue = value - oldValue
        newValue = oldValue + (dValue * v)

        unit = ''
        isTransform = false
        if k in ['translateX', 'translateY', 'translateZ']
          unit = 'px'
          isTransform = true
        else if k in ['rotateX', 'rotateY', 'rotateZ']
          unit = 'deg'
          isTransform = true
        else if k in ['scaleX', 'scaleY', 'scale']
          isTransform = true
          newValue = Math.max(newValue, 0)

        if isTransform
          transform += "#{k}(#{newValue}#{unit}) "
        else
          properties[k] = newValue

      css += "#{(t * 100)}% {\n"
      css += "#{BrowserSupport.transform()}: #{transform};\n" if transform
      for k, v of properties
        css += "#{k}: #{v};\n"
      css += " }\n"

      if t >= 1
        break
    css += "}\n"
    css

# Export
Dynamics =
  Animation: Animation
  Types:
    Spring: Spring
    SelfSpring: SelfSpring
    Gravity: Gravity
    GravityWithForce: GravityWithForce
    Linear: Linear
    Bezier: Bezier

try
  if module
    module.exports = Dynamics
  else
    @Dynamics = Dynamics
catch e
  @Dynamics = Dynamics