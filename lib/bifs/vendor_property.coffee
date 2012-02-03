# css terminology
# http://www.microsoft.com/typography/web/designer/css02.htm

stylus = require "stylus"
nodes  = stylus.nodes
utils  = stylus.utils
bifs   = stylus.functions
require "sugar"



###
options:
    property                css property property
    include_official    include @property without vendor prefixes
    is_vendor_value
    filterDeclaration
###
class VendorProperty
    defaults:
        include_official: yes
        is_vendor_value: no

    constructor: (options)->
        if not options.prefixes then throw "VendorProperty is missing @prefixes, the vendors associated with this css property"
        if not options.property then throw "VendorProperty is missing @property, the css property property"

        options = Object.merge @defaults, options

        #Structure the prefixes data-format and ensure each prefix has the right css format
        if Object.isString(options.prefixes)
            options.prefixes = options.prefixes.split(" ")
        options.prefixes = options.prefixes.map (prefix)->
            if prefix.first() isnt "-"
                prefix = prefix.padLeft("-")
            if prefix.last() isnt "-"
                prefix = prefix.padRight("-")
            prefix

        Object.merge @, options



    generateDeclarations: (value)->
        #TODO, styl_value correct?
        styl_value = value
        styl_property = new nodes.Expression()
        styl_property.push(new nodes.Literal(@property))
        styl_declarations = new nodes.Block()

        for prefix in @prefixes
            styl_prefix = new nodes.Expression()
            styl_prefix.push(new nodes.Literal(prefix))
            styl_declaration = @filterDeclaration(styl_prefix,styl_property,styl_value)
            styl_declarations.push(styl_declaration) if styl_declaration

        # WITHOUT VENDOR (THE ACTUAL-AND-OR-FUTURE CSS SPEC)
        if @include_official
            styl_declaration = @filterDeclaration("",styl_property,styl_value)
            styl_declarations.push(styl_declaration) if styl_declaration

        return styl_declarations

    filterDeclaration: (styl_prefix,styl_property,styl_value)->
        if @is_vendor_value
            if styl_prefix
                styl_prefix = styl_prefix.nodes[0].string
            #TODO the utils.unwrap method here is... confusing, why? I added it to handle ((val)) situations, but these situations are not present 100% of the time
            n = new nodes.Property([styl_property], styl_prefix+utils.unwrap(styl_value).first)
            n
        else
            new nodes.Property([styl_prefix,styl_property], styl_value)




class VendorIndex
    all_prefixes: [
        "moz"
        "ms"
        "o"
        "webkit"
    ]

    properties: {}

    ###

    prefixes: specific to the property being registered
    properties: to register
    options:
        ! see VendorProperty options !
        ! always auto provided options are: property, prefixes
        ! maybe  auto provided options are: is_vendor_value, value
    ###
    register: (prefixes,properties,options)->
        prefixes = @all_prefixes if prefixes.has(/\*|all/)

        for property in properties.trim().split(" ")
            property_data = Object.merge({prefixes:prefixes,property:property},options)

            if property.has(":")
                declaration = property
                [property,value] = declaration.split(":")
                property_data = Object.merge(property_data,{property:property,is_vendor_value:yes,value:value})

            @properties[property] = new VendorProperty property_data


    get: (property,value)->
        got_property = @properties[property.string]
        #TODO there are 3 or checks here. The 3rd is for vendor-values, the 2 is also for that? but was buggy and failed? but I kept it just in case it was for other reasons?
        # and the 1st is for... normal vendor-properties?
        if got_property and (not got_property.is_vendor_value or got_property.value is value.string or got_property.value is value?.nodes[0]?.nodes[0]?.string)
            got_property.generateDeclarations(value)
        # the declaration property or declaration value have no associated vendor
        else
            new nodes.Property([property], value)





# complicated cross-browser support to add:
# border-radius specific props
# transition
# when a vendor property is within a vendor-prefixed @keyframe, the properties need to be split each into their own respective keyframe....
#   i.e. http://moeedm.com/sandbox/pulse/#
# gradient
# flex + box

vendor_index = new VendorIndex()
vendor_index.register "moz", "background-origin background-size"
vendor_index.register "o ms", "text-overflow"
vendor_index.register "o moz webkit", "border-image"
vendor_index.register "moz webkit", "
 columns column-count column-span column-width column-gap column-rule column-rule-width column-rule-style column-rule-color
 border-radius
 box-sizing
 box-shadow
 background-clip
 font-feature-settings"
vendor_index.register "*", "
 object-fit object-position
 transform transform-origin backface-visibility
 transition transition-delay transition-duration transition-timeing-function transition-property
 animation animation-delay animation-direction animation-duration animation-fill-mode animation-iteration-count animation-name animation-play-state animation-timing-function
 box-orient box-pack box-align box-ordinal-group box-direction box-flex box-flex-group box-lines box-sizing
 hyphens
 user-modify user-select
 display:box"







(exports.vendorizeProperty = (property,value)->

    # ASSERTING

    #utils.assertType(property, 'expression', 'property')
    property = utils.unwrap(property).first
    #utils.assertString(property, 'property')

    #utils.assertType(value, 'expression', 'expr')
    #value = utils.unwrap(value).first
    #value = bifs.unquote(value)
    #utils.assertString(value, 'expr')

    if property.nodeName is "function"
        #property.params.nodes.push value
        #a=new nodes.Function(property.name,property.params,property.block)
        new nodes.Property(["color"],value)
    else
        vendor_index.get(property,value)



).raw = true
