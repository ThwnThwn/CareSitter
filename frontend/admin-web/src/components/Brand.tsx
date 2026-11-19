import mark from '../assets/caresitter-mark.png';

export function Brand() {
  return <div className="brand" aria-label="CareSitter · Quản trị">
    <img src={mark} width="44" height="44" alt="" />
    <span><strong>CareSitter</strong><small>Quản trị vận hành</small></span>
  </div>;
}
