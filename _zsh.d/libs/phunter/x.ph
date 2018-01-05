This is $PID
#------------------------------------------| @echo
Hello PH!
#------------------------------------------| @tree
# ROOT
    * packageName: a
    * age: 2
## persons
### person
    * name: $packageName
    * age: 2
### person
    * name: 1
    * age: ${name}_1
#### banks
    * name: CIBC
    * code: 1982
## test
    * A
    * B
#-------------------------------------| @stop
#-------------------------------------| @match /person
class $name {
#----------------------| type name value -- $
    private $type $name = $value; // $comment
#----------------------
    public $type get$name() {
        return this.$name;
    }
#----------------------
    public void set$name($type $name) {
        this.$name = $name;
    }
}

#-------------------------------------| @function type -- name type | @append sdfasdf

private $type $name = $default_value[$type];

#-------------------------------------
- root:
    - person
        - name: 1
        - age: 2
    - person
        - name: 1
        - age: 2
    - person
        - name: 1
        - age: 2
        
#   /person/name -> person_name
#   ph_context=person $person_name
#------------------------------------------| @match * | @append members
private $TYPE $NAME = 0;
$(hello )

#------------------------------------------| @function hello
$KEY=$VALUE;
${KES.BIG.MAP}
${KES.BIG.MAP[1]})

#------------------------------------------| @function hello
$KEY=$VALUE;
${KES.BIG.MAP}
${KES.BIG.MAP[1]}
$person.name
$person.age
$person.bank[1]

#------------------------------------------| @match * object
package $PACKAGE:


$person.name
$person.age
$person.bank[1]

#------------------------------------------| @match * object
package $PACKAGE:

public class $CLASSNAME {
    $members

    $members
}

#------------------------------------------|
This is function test

#------------------------------------------| @match * | @append methods
public $TYPE get$NAME() {
    return this.$NAME;
}

public CLASSNAME set$NAME($TYPE $NAME) {
    this.$NAME = $NAMEl
    return this;
}

