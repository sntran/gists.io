/** @jsx React.DOM */
var Text = React.createClass({
    getInitialState: function() {
        return {data: ""};
    },
    componentWillMount: function() {
        // Before the form is rendered, connect to server
        var self = this;
        
    },
    render: function() {
        return (
            <div contentEditable='true'>
                
            </div>
        );
    }
});