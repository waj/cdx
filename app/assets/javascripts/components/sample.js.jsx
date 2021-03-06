var AddItemSearchSampleTemplate = React.createClass({
  render: function() {
    return (<span>{this.props.item.entity_id} ({this.props.item.uuid})</span>);
  }
});

var Sample = React.createClass({
  render: function() {
    // TODO add barcode
    // TODO add printer
    return (
    <li>
     {this.props.sample.entity_id} ({this.props.sample.uuid})
    </li>);
  }
});

var SamplesList = React.createClass({
  render: function() {
    return (
      <ul>
        {this.props.samples.map(function(sample) {
           return <Sample key={sample.uuid} sample={sample}/>;
        })}
      </ul>
    );
  }
});
